describe ActivityNotification::NotificationsController, type: :controller do
  let(:test_target) { create(:user) }
  let(:valid_session) {}

  describe "GET #index" do
    context "with target_type and target_id parameters" do
      before do
        @notification = create(:notification, target: test_target)
        get :index, { target_type: :users, target_id: test_target, user_id: 'dummy' }, valid_session
      end

      it "returns 200 as http status code" do
        expect(response.status).to eq(200)
      end

      it "assigns notification index as @notifications" do
        expect(assigns(:notifications)).to eq([@notification])
      end

      it "renders the :index template" do
        expect(response).to render_template :index
      end
    end

    context "with target_type and user_id parameters" do
      before do
        @notification = create(:notification, target: test_target)
        get :index, { target_type: :users, user_id: test_target }, valid_session
      end
  
      it "returns 200 as http status code" do
        expect(response.status).to eq(200)
      end

      it "assigns notification index as @notifications" do
        expect(assigns(:notifications)).to eq([@notification])
      end

      it "renders the :index template" do
        expect(response).to render_template :index
      end
    end

    context "without target_type parameters" do
      before do
        @notification = create(:notification, target: test_target)
        get :index, { user_id: test_target }, valid_session
      end

      it "returns 400 as http status code" do
        expect(response.status).to eq(400)
      end
    end

    context "with not found user_id parameter" do
      before do
        @notification = create(:notification, target: test_target)
      end

      it "raises ActiveRecord::RecordNotFound" do
        expect {
          get :index, { target_type: :users, user_id: 0 }, valid_session
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "with json as format parameter" do
      before do
        @notification = create(:notification, target: test_target)
        get :index, { target_type: :users, user_id: test_target, format: :json }, valid_session
      end

      it "returns 200 as http status code" do
        expect(response.status).to eq(200)
      end

      it "returns json format" do
        expect(JSON.parse(response.body).first)
        .to include("target_id" => test_target.id, "target_type" => "User")
      end
    end

    context "with filter parameter" do
      context "with unopened as filter" do
        before do
          @notification = create(:notification, target: test_target)
          get :index, { target_type: :users, user_id: test_target, filter: 'unopened' }, valid_session
        end

        it "assigns unopened notification index as @notifications" do
          expect(assigns(:notifications)).to eq([@notification])
        end
      end

      context "with opened as filter" do
        before do
          @notification = create(:notification, target: test_target)
          get :index, { target_type: :users, user_id: test_target, filter: 'opened' }, valid_session
        end

        it "assigns unopened notification index as @notifications" do
          expect(assigns(:notifications)).to eq([])
        end
      end
    end

    context "with limit parameter" do
      before do
        create(:notification, target: test_target)
        create(:notification, target: test_target)
      end
      context "with 2 as limit" do
        before do
          get :index, { target_type: :users, user_id: test_target, limit: 2 }, valid_session
        end

        it "assigns notification index of size 2 as @notifications" do
          expect(assigns(:notifications).size).to eq(2)
        end
      end

      context "with 1 as limit" do
        before do
          get :index, { target_type: :users, user_id: test_target, limit: 1 }, valid_session
        end

        it "assigns notification index of size 1 as @notifications" do
          expect(assigns(:notifications).size).to eq(1)
        end
      end
    end

    context "with reload parameter" do
      context "with false as reload" do
        before do
          @notification = create(:notification, target: test_target)
          get :index, { target_type: :users, user_id: test_target, reload: false }, valid_session
        end
    
        it "returns 200 as http status code" do
          expect(response.status).to eq(200)
        end
  
        it "does not assign notification index as @notifications" do
          expect(assigns(:notifications)).to be_nil
        end
  
        it "renders the :index template" do
          expect(response).to render_template :index
        end
      end
    end
  end

  describe "POST #open_all" do
    context "http direct POST request" do
      before do
        @notification = create(:notification, target: test_target)
        expect(@notification.opened?).to be_falsey
        post :open_all, { target_type: :users, user_id: test_target }, valid_session
      end

      it "returns 302 as http status code" do
        expect(response.status).to eq(302)
      end

      it "assigns notification index as @notifications" do
        expect(assigns(:notifications)).to eq([@notification])
      end

      it "opens all notifications of the target" do
        expect(assigns(:notifications).first.opened?).to be_truthy
      end

      it "redirects to :index" do
        expect(response).to redirect_to user_notifications_path(test_target)
      end
    end

    context "http POST request from :show" do
      before do
        @notification = create(:notification, target: test_target)
        expect(@notification.opened?).to be_falsey
        request.env["HTTP_REFERER"] = user_notification_path(test_target, @notification)
        post :open_all, { target_type: :users, user_id: test_target }, valid_session
      end

      it "returns 302 as http status code" do
        expect(response.status).to eq(302)
      end

      it "opens all notifications of the target" do
        expect(assigns(:notifications).first.opened?).to be_truthy
      end

      it "redirects to :show as request.referer" do
        expect(response).to redirect_to user_notification_path(test_target, @notification)
      end
    end

    context "Ajax POST request" do
      before do
        @notification = create(:notification, target: test_target)
        expect(@notification.opened?).to be_falsey
        xhr :post, :open_all, { target_type: :users, user_id: test_target }, valid_session
      end

      it "returns 200 as http status code" do
        expect(response.status).to eq(200)
      end

      it "assigns notification index as @notifications" do
        expect(assigns(:notifications)).to eq([@notification])
      end

      it "opens all notifications of the target" do
        expect(assigns(:notifications).first.opened?).to be_truthy
      end

      it "renders the :open_all template as format js" do
        expect(response).to render_template :open_all, format: :js
      end
    end
  end

  describe "GET #show" do
    context "with id, target_type and user_id parameters" do
      before do
        @notification = create(:notification, target: test_target)
        get :show, { id: @notification, target_type: :users, user_id: test_target }, valid_session
      end

      it "returns 200 as http status code" do
        expect(response.status).to eq(200)
      end

      it "assigns the requested notification as @notification" do
        expect(assigns(:notification)).to eq(@notification)
      end

      it "renders the :index template" do
        expect(response).to render_template :show
      end
    end

    context "with wrong id and user_id parameters" do
      before do
        @notification = create(:notification, target: create(:user))
        get :show, { id: @notification, target_type: :users, user_id: test_target }, valid_session
      end

      it "returns 403 as http status code" do
        expect(response.status).to eq(403)
      end
    end
  end

  describe "DELETE #destroy" do
    context "http direct DELETE request" do
      before do
        @notification = create(:notification, target: test_target)
        delete :destroy, { id: @notification, target_type: :users, user_id: test_target }, valid_session
      end

      it "returns 302 as http status code" do
        expect(response.status).to eq(302)
      end

      it "deletes the notification" do
        expect(assigns(test_target.notifications.where(id: @notification.id).exists?)).to be_falsey
      end

      it "redirects to :index" do
        expect(response).to redirect_to user_notifications_path(test_target)
      end
    end

    context "http DELETE request from :show" do
      before do
        @notification = create(:notification, target: test_target)
        request.env["HTTP_REFERER"] = user_notification_path(test_target, @notification)
        delete :destroy, { id: @notification, target_type: :users, user_id: test_target }, valid_session
      end

      it "returns 302 as http status code" do
        expect(response.status).to eq(302)
      end

      it "deletes the notification" do
        expect(assigns(test_target.notifications.where(id: @notification.id).exists?)).to be_falsey
      end

      it "redirects to :show as request.referer" do
        expect(response).to redirect_to user_notification_path(test_target, @notification)
      end
    end

    context "Ajax DELETE request" do
      before do
        @notification = create(:notification, target: test_target)
        xhr :delete, :destroy, { id: @notification, target_type: :users, user_id: test_target }, valid_session
      end

      it "returns 200 as http status code" do
        expect(response.status).to eq(200)
      end

      it "assigns notification index as @notifications" do
        expect(assigns(:notifications)).to eq([])
      end

      it "deletes the notification" do
        expect(assigns(test_target.notifications.where(id: @notification.id).exists?)).to be_falsey
      end

      it "renders the :destroy template as format js" do
        expect(response).to render_template :destroy, format: :js
      end
    end
  end

  describe "POST #open" do
    context "without move parameter" do
      context "http direct POST request" do
        before do
          @notification = create(:notification, target: test_target)
          expect(@notification.opened?).to be_falsey
          post :open, { id: @notification, target_type: :users, user_id: test_target }, valid_session
        end

        it "returns 302 as http status code" do
          expect(response.status).to eq(302)
        end

        it "opens the notification" do
          expect(@notification.reload.opened?).to be_truthy
        end

        it "redirects to :index" do
          expect(response).to redirect_to user_notifications_path(test_target)
        end
      end

      context "http POST request from :show" do
        before do
          @notification = create(:notification, target: test_target)
          expect(@notification.opened?).to be_falsey
          request.env["HTTP_REFERER"] = user_notification_path(test_target, @notification)
          post :open, { id: @notification, target_type: :users, user_id: test_target }, valid_session
        end

        it "returns 302 as http status code" do
          expect(response.status).to eq(302)
        end

        it "opens the notification" do
          expect(@notification.reload.opened?).to be_truthy
        end

        it "redirects to :show as request.referer" do
          expect(response).to redirect_to user_notification_path(test_target, @notification)
        end
      end

      context "Ajax POST request" do
        before do
          @notification = create(:notification, target: test_target)
          expect(@notification.opened?).to be_falsey
          request.env["HTTP_REFERER"] = user_notification_path(test_target, @notification)
          xhr :post, :open, { id: @notification, target_type: :users, user_id: test_target }, valid_session
        end
    
        it "returns 200 as http status code" do
          expect(response.status).to eq(200)
        end
    
        it "assigns notification index as @notifications" do
          expect(assigns(:notifications)).to eq([@notification])
        end
  
        it "opens the notification" do
          expect(@notification.reload.opened?).to be_truthy
        end
  
        it "renders the :open template as format js" do
          expect(response).to render_template :open, format: :js
        end
      end
    end

    context "with true as move parameter" do
      context "http direct POST request" do
        before do
          @notification = create(:notification, target: test_target)
          expect(@notification.opened?).to be_falsey
          post :open, { id: @notification, target_type: :users, user_id: test_target, move: true }, valid_session
        end

        it "returns 302 as http status code" do
          expect(response.status).to eq(302)
        end

        it "assigns notification index as @notifications" do
          expect(assigns(:notifications)).to eq([@notification])
        end

        it "opens the notification" do
          expect(@notification.reload.opened?).to be_truthy
        end

        it "redirects to notifiable_path" do
          expect(response).to redirect_to @notification.notifiable_path
        end
      end
    end
  end

  describe "GET #move" do
    context "without open parameter" do
      context "http direct GET request" do
        before do
          @notification = create(:notification, target: test_target)
          get :move, { id: @notification, target_type: :users, user_id: test_target }, valid_session
        end

        it "returns 302 as http status code" do
          expect(response.status).to eq(302)
        end

        it "redirects to notifiable_path" do
          expect(response).to redirect_to @notification.notifiable_path
        end
      end
    end

    context "with true as open parameter" do
      context "http direct GET request" do
        before do
          @notification = create(:notification, target: test_target)
          expect(@notification.opened?).to be_falsey
          get :move, { id: @notification, target_type: :users, user_id: test_target, open: true }, valid_session
        end

        it "returns 302 as http status code" do
          expect(response.status).to eq(302)
        end

        it "opens the notification" do
          expect(@notification.reload.opened?).to be_truthy
        end

        it "redirects to notifiable_path" do
          expect(response).to redirect_to @notification.notifiable_path
        end
      end
    end
  end

end
