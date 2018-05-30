class BotsController < ApplicationController
  before_action :authenticated!, except: [:index, :show, :hook]
  before_action :set_bot, only: [:show, :show_storage, :edit, :update, :destroy]
  before_action :check_permission!, except: [:index, :hook, :new, :create]

  # GET /bots
  def index
    @bots = Bot.all
  end

  # GET /bots/1
  def show
  end

  # GET /bots/1/storage
  def show_storage
    @storage_table = JSON.parse(@bot.storage.content || '{}')
  end

  # GET  /bots/1/hook
  # POST /bots/1/hook
  def hook
    if Bot.exists?(params[:id])
      JobDaemon.enqueue(JobDaemons::BotJob.new(params[:id].to_i, 'onHook', [request.method, hook_params]))
      render json: {status: 'ok'}, status: :ok
    else
      render json: {status: 'ng'}, status: :not_found
    end
  end

  # GET /bots/new
  def new
    @bot = Bot.new.tap do |bot|
      bot.user = current_user
      bot.script = <<'EOS'
function initialize() {
}

function onTalk(name, text) {
  if(text=="Hello!") {
    api.slack.talk("Bot Heaven!");
  }
}
EOS
    end
  end

  # GET /bots/1/edit
  def edit
  end

  # POST /bots
  def create
    @bot = Bot.new(bot_params).tap do |bot|
      bot.user = current_user
    end

    if @bot.save
      @bot.fetch_bot_modules(bot_modules_params)
      call_initializer
      invite_bot
      redirect_to @bot, notice: 'Bot was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /bots/1
  def update
    if @bot.update(bot_params)
      @bot.fetch_bot_modules(bot_modules_params)
      call_initializer
      invite_bot
      redirect_to @bot, notice: 'Bot was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /bots/1
  def destroy
    @bot.destroy
    redirect_to bots_url, notice: 'Bot was successfully destroyed.'
  end

  private
  # Call bot initializer.
  def call_initializer
    JobDaemon.enqueue(JobDaemons::BotJob.new(@bot.id, 'initialize', []))
  end

  # Invite HeavenBot to bot channel.
  def invite_bot
    SlackUtils::SingletonClient.instance.invite_channel(@bot.channel_id, Bot.slack_bot_id, session[:token])
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_bot
    @bot = Bot.find(params[:id])
  end

  # Check Permission.
  def check_permission!
    case action_name
      when 'show'
        redirect_to root_path unless @bot.readable?(current_user)
      when 'edit', 'update', 'show_storage'
        redirect_to root_path unless @bot.editable?(current_user)
      when 'destroy'
        redirect_to root_path unless @bot.owner?(current_user)
      else
        raise "Unknown action #{action_name}"
    end
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def bot_params
    params.require(:bot).permit(:name, :channel, :default_icon, :permission, :script)
  end

  # Bot Module Parameters.
  # @return [Array<Integer>] Array of BotModule ID.
  def bot_modules_params
    if params[:bot] and params[:bot][:modules]
      params[:bot][:modules].map(&:to_i)
    else
      []
    end
  end

  # Hook Parameters.
  # @return [Hash<String,String>] Hash of Bot Hook.
  def hook_params
    params.except(:id, :action, :controller).to_unsafe_h
  end
end
