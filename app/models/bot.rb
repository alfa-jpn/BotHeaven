# class of Bot.
# @attr [Integer]           id            Bot ID.
# @attr [String]            name          Name of bot.
# @attr [String]            channel       Channel Name of bot.
# @attr [String]            channel_id    ID of channel.
# @attr [User]              user          Author of bot.
# @attr [String]            default_icon  Default Icon of bot.
# @attr [String]            script        Script of bot.
# @attr [String]            current_error Current Error of bot. When bot does not have error, This value is Empty.
# @attr [Bots::Permissions] permission    Permission of bot.
class Bot < ActiveRecord::Base
  SCRIPT_TIMEOUT = 1000
  class V8ContextException < StandardError; end

  after_create :create_default_storage
  before_save :set_channel_id

  belongs_to :user,            inverse_of: :bots
  has_one    :storage,         inverse_of: :bot, dependent: :destroy
  has_many   :alarms,          inverse_of: :bot, dependent: :destroy
  has_many   :bot_bot_modules, inverse_of: :bot, dependent: :destroy
  has_many   :bot_modules, through: :bot_bot_modules

  bind_inum :permission, Bots::Permissions

  validates :name,         presence: true, length: {in: 1..32}, format: {with: /\A[A-Za-z0-9_-]+\Z/}
  validates :channel,      presence: true, length: {in: 1..32}, format: {with: /\A[A-Za-z0-9_-]+\Z/}
  validates :user,         presence: true
  validates :default_icon, length: {maximum: 32}, format: {with: /\A\w*\Z/}
  validates :script,       presence: true, length: {in: 1..64.kilobytes}

  # Execute Function of bot script.
  # @param [String] function name of function.
  # @param [Array]  arguments.
  # @return [String] eval of function.
  def execute_function(function, arguments: [])
    GC.disable
    cxt = V8::Context.new(timeout: SCRIPT_TIMEOUT)
    raise V8ContextException.new unless cxt.native
    cxt['api'] = Bots::API.new(self)
    cxt.eval modules_imported_script
    cxt['bot_function_params'] = arguments
    cxt.eval("#{function}.apply(this, bot_function_params)").to_s
  rescue V8ContextException
    reload_v8!
  rescue => e
    update_column(:current_error, "#{Time.zone.now} - #{e.to_s}")
    nil
  ensure
    cxt.dispose unless cxt.nil?
    GC.enable
  end

  # Fetch BotModules from usable modules.
  # @param [Array<Integer>] bot_module_ids Array of BotModule ID.
  def fetch_bot_modules(bot_module_ids)
    self.bot_modules = BotModule.usable(self).where(id: bot_module_ids)
  end

  # Get Channel ID.
  # @return [String] ID of channel.
  def channel_id
    cid = super
    if cid.present?
      cid
    else
      SlackUtils::SingletonClient.instance.find_channel_id(channel).tap do |cid|
        update_column(:channel_id, cid) if cid
      end
    end
  end

  # Check if has permission for edit.
  # @param [User] user User
  # @return [Boolean] true if user has permission.
  def editable?(user)
    owner?(user) || permission == Bots::Permissions::FREEDOM_BOT
  end

  # Check if owner.
  # @param [User] user User
  # @return [Boolean] true if user is owner.
  def owner?(user)
    if user
      self.user_id == user.id
    else
      false
    end
  end

  # Check if has permission for read.
  # @param [User] user User
  # @return [Boolean] true if user has permission.
  def readable?(user)
    owner?(user) || permission != Bots::Permissions::PRIVATE_BOT
  end

  # Return Slack Bot ID.
  # @return [String] ID of SlackBot.
  def self.slack_bot_id
    if @slack_bot_id.present?
      @slack_bot_id
    else
      @slack_bot_id = SlackUtils::SingletonClient.instance.find_user_id(
          Rails.application.secrets.slack_bot_name
      )
    end
  end

  private
  # Get modules imported script.
  # @return [String] Modules imported script
  def modules_imported_script
    Array.new.tap { |scripts|
      scripts.concat bot_modules.usable(self).map(&:script)
      scripts.push self.script
    }.join('')
  end

  # Reload V8
  # @note very very very uncool!
  def reload_v8!
    Object.send(:remove_const, :V8)
    $".delete_if {|m| m.include?('v8')}
    require 'v8'
  end

  # Set channel id.
  def set_channel_id
    self.channel_id = SlackUtils::SingletonClient.instance.find_channel_id(channel)
  end

  # Create bot storage.
  def create_default_storage
    create_storage!(content: '{}')
  end
end
