#encoding: utf-8
require 'spec/spec_helper'

describe 'REST API:' do
  
  before(:each) { 
    start_slanger_with_mongo 
    cleanup_db
  }

  describe 'applications' do
    context 'can be created with the REST API' do
      before :each do
        @created_app_response = rest_api_post('/applications.json')
        @created_app = JSON::parse(@created_app_response.body)
      end

      it 'and will appear in MongoDB' do
        # Retrieve app in mongo db to check that it actually was created
        mongo_app = get_application(@created_app['id'])
        @created_app_response.code.should eq('201')
        @created_app['id'].should_not be_nil
        @created_app['key'].should_not be_nil
        @created_app['secret'].should_not be_nil

        mongo_app.should_not be_nil
        mongo_app['_id'].should_not be_nil
        mongo_app['_id'].should eq(@created_app['id'])
        mongo_app['key'].should_not be_nil
        mongo_app['key'].should eq(@created_app['key'])
        mongo_app['secret'].should_not be_nil
        mongo_app['secret'].should eq(@created_app['secret'])
      end

      it 'and will be listed with the REST API' do
        # list apps
        response = rest_api_get('/applications.json')
        returned_apps = JSON::parse(response.body)

        response.code.should eq('200')
        returned_apps.count.should eq(1)
      end
 
      it 'and can be deleted with the REST API' do
        # list apps
        response = rest_api_get('/applications.json')
        apps_before_delete = JSON::parse(response.body)
        # delete it
        delete_response = rest_api_delete('/applications/' + apps_before_delete[0]['id'].to_s + '.json')
        # list apps again
        response = rest_api_get('/applications.json')
        apps_after_delete = JSON::parse(response.body)
 
        delete_response.code.should eq('204')
        apps_before_delete.count.should eq(1)
        apps_after_delete.count.should eq(0)
      end
 
      it 'can have their token changed via the REST API' do
        # change app token
        change_token_response = rest_api_put("/applications/#{@created_app['id']}/generate_new_token.json")
        app_after_change = JSON::parse(change_token_response.body)
        # get it again
        response = rest_api_get("/applications/#{@created_app['id']}.json")
        app_retrieved_after_change = JSON::parse(response.body)
 
        @created_app['id'].should_not be_nil
        @created_app['id'].should eq app_after_change['id']
        @created_app['key'].should_not be_nil
        @created_app['key'].should_not eq app_after_change['key']
        @created_app['secret'].should_not be_nil
        @created_app['secret'].should_not eq app_after_change['secret']
        app_retrieved_after_change['id'].should_not be_nil
        app_retrieved_after_change['id'].should eq app_after_change['id']
        app_retrieved_after_change['key'].should_not be_nil
        app_retrieved_after_change['key'].should eq app_after_change['key']
        app_retrieved_after_change['secret'].should_not be_nil
        app_retrieved_after_change['secret'].should eq app_after_change['secret']
      end


      it 'and cannot have their keys changed via the API' do
        # change app key
        changed_app = @created_app.clone()
        changed_app['key'] = "changedkey"
        change_response = rest_api_put("/applications/#{@created_app['id']}.json", {application: changed_app}.to_json)

        # get it again
        response = rest_api_get("/applications/#{@created_app['id']}.json")
        app_after_change = JSON::parse(response.body)
 
        @created_app['id'].should_not be_nil
        @created_app['id'].should eq app_after_change['id']
        @created_app['key'].should_not be_nil
        @created_app['key'].should eq app_after_change['key']
        @created_app['secret'].should_not be_nil
        @created_app['secret'].should eq app_after_change['secret']
        change_response.code.should eq "403" 
      end

      it 'and cannot have their secrets changed via the API' do
        # change app secret
        changed_app = @created_app.clone()
        changed_app['secret'] = "changedsecret"
        change_response = rest_api_put("/applications/#{@created_app['id']}.json", {application: changed_app}.to_json)

        # get it again
        response = rest_api_get("/applications/#{@created_app['id']}.json")
        app_after_change = JSON::parse(response.body)
 
        @created_app['id'].should_not be_nil
        @created_app['id'].should eq app_after_change['id']
        @created_app['key'].should_not be_nil
        @created_app['key'].should eq app_after_change['key']
        @created_app['secret'].should_not be_nil
        @created_app['secret'].should eq app_after_change['secret']
        change_response.code.should eq "403" 
      end

      it 'and can have their webhook url changed via the API' do
        # change app webhook
        changed_app = @created_app.clone()
        changed_app['webhook_url'] = "http://example.com/hook"
        change_response = rest_api_put("/applications/#{@created_app['id']}.json", {application: changed_app}.to_json)

        # get it again
        response = rest_api_get("/applications/#{@created_app['id']}.json")
        app_after_change = JSON::parse(response.body)
 
        @created_app['id'].should_not be_nil
        @created_app['id'].should eq app_after_change['id']
        @created_app['key'].should_not be_nil
        @created_app['key'].should eq app_after_change['key']
        @created_app['secret'].should_not be_nil
        @created_app['secret'].should eq app_after_change['secret']
        app_after_change['webhook_url'].should eq "http://example.com/hook"
        change_response.code.should eq "204" 
      end

      it 'and can have their nb_message_limit changed via the API' do
        # change app webhook
        changed_app = @created_app.clone()
        changed_app['nb_message_limit'] = 5
        change_response = rest_api_put("/applications/#{@created_app['id']}.json", {application: changed_app}.to_json)

        # get it again
        response = rest_api_get("/applications/#{@created_app['id']}.json")
        app_after_change = JSON::parse(response.body)
 
        @created_app['id'].should_not be_nil
        @created_app['id'].should eq app_after_change['id']
        @created_app['key'].should_not be_nil
        @created_app['key'].should eq app_after_change['key']
        @created_app['secret'].should_not be_nil
        @created_app['secret'].should eq app_after_change['secret']
        app_after_change['nb_message_limit'].should eq 5
        change_response.code.should eq "204" 
      end
 
      it 'and can have their connectionn_limit changed via the API' do
        # change app webhook
        changed_app = @created_app.clone()
        changed_app['connection_limit'] = 5
        change_response = rest_api_put("/applications/#{@created_app['id']}.json", {application: changed_app}.to_json)

        # get it again
        response = rest_api_get("/applications/#{@created_app['id']}.json")
        app_after_change = JSON::parse(response.body)
 
        @created_app['id'].should_not be_nil
        @created_app['id'].should eq app_after_change['id']
        @created_app['key'].should_not be_nil
        @created_app['key'].should eq app_after_change['key']
        @created_app['secret'].should_not be_nil
        @created_app['secret'].should eq app_after_change['secret']
        app_after_change['connection_limit'].should eq 5
        change_response.code.should eq "204" 
      end
 
    end
  end
end
