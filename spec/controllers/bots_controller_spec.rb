require 'rails_helper'

RSpec.describe BotsController, type: :controller do
  fixtures :users
  fixtures :bots
  fixtures :bot_modules
  fixtures :bot_bot_modules
  fixtures :storages

  let :bot do
    Bot.find(1)
  end

  let :user do
    User.find(1)
  end

  let :valid_attributes do
    {
      name:         'valid_attributes',
      channel:      'random',
      default_icon: 'tikuwa',
      permission:   2,
      script:       'function initialize(){};',
      user:         user,
      modules:      [1]
    }
  end

  let :invalid_attributes do
    {name: 'aaaaaaaaaaaaa' * 10}
  end

  before(:each) do
    login(user)
  end

  describe "GET #index" do
    subject do
      get :index
      response
    end

    it 'Render index.' do
      expect(subject).to render_template(:index)
    end
  end

  describe "GET #new" do
    subject do
      get :new
      response
    end

    it 'Render new.' do
      expect(subject).to render_template(:new)
    end
  end


  describe "GET #show" do
    subject do
      get :show, params: {id: bot.to_param}
      response
    end

    it 'Render show.' do
      expect(subject).to render_template(:show)
    end

    context 'When private bot' do
      let :bot do
        Bot.find(2)
      end

      it 'Redirect to root' do
        expect(subject).to redirect_to(root_path)
      end
    end
  end

  describe "GET #show_storage" do
    subject do
      get :show_storage, params: {id: bot.to_param}
      response
    end

    it 'Render show_storage.' do
      expect(subject).to render_template(:show_storage)
    end

    context 'When private bot' do
      let :bot do
        Bot.find(2)
      end

      it 'Redirect to root' do
        expect(subject).to redirect_to(root_path)
      end
    end
  end

  describe "GET #hook" do
    subject do
      get :hook, params: {id: bot.to_param, original_param: 123}
      response
    end

    it 'Status 200' do
      expect(subject.status).to eq(200)
    end

    it 'Enqueue bot job' do
      expect(JobDaemons::BotJob).to receive(:new).with(bot.id, 'onHook', ['GET', {'original_param' => '123'}]).once
      expect(JobDaemon).to receive(:enqueue).once
      subject
    end
  end

  describe "POST #hook" do
    subject do
      post :hook, params: {id: bot.to_param, original_param: {item: ['ruby']}}
      response
    end

    it 'Status 200' do
      expect(subject.status).to eq(200)
    end

    it 'Enqueue bot job' do
      expect(JobDaemons::BotJob).to receive(:new).with(bot.id, 'onHook', ['POST', {'original_param' => {'item' => ['ruby']}}]).once
      expect(JobDaemon).to receive(:enqueue).once
      subject
    end
  end

  describe "GET #edit" do
    subject do
      get :edit, params: {id: bot.to_param}
      response
    end

    it 'Render edit.' do
      expect(subject).to render_template(:edit)
    end

    context 'When private bot' do
      let :bot do
        Bot.find(2)
      end

      it 'Redirect to root' do
        expect(subject).to redirect_to(root_path)
      end
    end
  end


  describe "POST #create" do
    context "with valid params" do
      subject do
        post :create, params: {bot: valid_attributes}
      end

      it "creates a new Bot" do
        expect {
          subject
        }.to change(Bot, :count).by(1)
      end

      it "assigns a newly created bot as @bot" do
        subject
        expect(assigns(:bot)).to be_a(Bot)
        expect(assigns(:bot)).to be_persisted
      end

      it "redirects to the created bot" do
        subject
        expect(response).to redirect_to(Bot.last)
      end

      it 'associated bot_modules' do
        subject
        expect(bot.bot_modules.pluck(:id)).to eq([1])
      end

      it 'enqueue initializer job.' do
        expect(JobDaemon).to receive(:enqueue)
        subject
      end

      it 'invite bot to channel.' do
        expect(SlackUtils::SingletonClient.instance).to receive(:invite_channel)
        subject
      end
    end

    context "with invalid params" do
      subject do
        post :create, params: {bot: invalid_attributes}
      end

      it "assigns a newly created but unsaved bot as @bot" do
        subject
        expect(assigns(:bot)).to be_a_new(Bot)
      end

      it "re-renders the 'new' template" do
        subject
        expect(response).to render_template("new")
      end
    end
  end

  describe "PUT #update" do
    context "with valid params" do
      let(:new_attributes) {
        { name: 'alfa', channel: 'alfa_test', modules: [3] }
      }

      subject do
        put :update, params: {id: bot.to_param, bot: new_attributes}
      end

      it "updates the requested bot" do
        subject
        bot.reload
        expect(bot.name).to eq('alfa')
      end

      it "assigns the requested bot as @bot" do
        subject
        expect(assigns(:bot)).to eq(bot)
      end

      it "redirects to the bot" do
        subject
        expect(response).to redirect_to(bot)
      end

      it 'updated bot_modules' do
        expect{
          subject
        }.to change {
           bot.reload.bot_modules.pluck(:id)
        }.from([1]).to([3])
      end

      it 'enqueue initializer job.' do
        expect(JobDaemon).to receive(:enqueue)
        subject
      end

      it 'invite bot to channel.' do
        expect(SlackUtils::SingletonClient.instance).to receive(:invite_channel)
        subject
      end

      context 'When not freedom bot' do
        let :bot do
          Bot.find(2)
        end

        it 'Redirect to root' do
          expect(subject).to redirect_to(root_path)
        end
      end
    end

    context "with invalid params" do
      it "assigns the bot as @bot" do
        put :update, params: {id: bot.to_param, bot: invalid_attributes}
        expect(assigns(:bot)).to eq(bot)
      end

      it "re-renders the 'edit' template" do
        put :update, params: {id: bot.to_param, bot: invalid_attributes}
        expect(response).to render_template("edit")
      end
    end
  end

  describe "DELETE #destroy" do
    it "destroys the requested bot" do
      expect {
        delete :destroy, params: {id: bot.to_param}
      }.to change(Bot, :count).by(-1)
    end

    it "redirects to the bots list" do
      delete :destroy, params: {id: bot.to_param}
      expect(response).to redirect_to(bots_url)
    end

    context 'When not owner' do
      let :bot do
        Bot.find(2)
      end

      it 'Redirect to root' do
        expect(delete :destroy, params: {id: bot.to_param}).to redirect_to(root_path)
      end
    end
  end
end
