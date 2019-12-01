module ActivityNotification
  module ControllerSpec
    module RequestUtility
      def get_with_compatibility action, params, session
        if Rails::VERSION::MAJOR <= 4
          get action, params, session
        else
          get action, params: params, session: session
        end
      end

      def post_with_compatibility action, params, session
        if Rails::VERSION::MAJOR <= 4
          post action, params, session
        else
          post action, params: params, session: session
        end
      end

      def put_with_compatibility action, params, session
        if Rails::VERSION::MAJOR <= 4
          put action, params, session
        else
          put action, params: params, session: session
        end
      end

      def delete_with_compatibility action, params, session
        if Rails::VERSION::MAJOR <= 4
          delete action, params, session
        else
          delete action, params: params, session: session
        end
      end

      def xhr_with_compatibility method, action, params, session
        if Rails::VERSION::MAJOR <= 4
          xhr method, action, params, session
        else
          send method.to_s, action, xhr: true, params: params, session: session
        end
      end
    end

    module ApiResponseUtility
      def response_json
        JSON.parse(response.body)
      end

      def assert_json_with_array_size(json_array, size)
        expect(json_array.size).to eq(size)
      end

      def assert_json_with_object(json_object, object)
        expect(json_object['id'].to_s).to eq(object.id.to_s)
      end

      def assert_json_with_object_array(json_array, expected_object_array)
        assert_json_with_array_size(json_array, expected_object_array.size)
        expected_object_array.each_with_index do |json_object, index|
          assert_json_with_object(json_object, expected_object_array[index])
        end
      end

      def assert_error_response(code)
        expect(response_json['gem']).to eq('activity_notification')
        expect(response_json['error']['code']).to eq(code)
      end
    end

    module CommitteeUtility
      extend ActiveSupport::Concern
      included do
        include Committee::Rails::Test::Methods

        def api_path
          "/#{root_path}/#{target_type}/#{test_target.id}"
        end
  
        def schema_path
          Rails.root.join('..', 'openapi.json') 
        end
  
        def write_schema_file(schema_json)
          File.open(schema_path, "w") { |file| file.write(schema_json) }
        end
  
        def read_schema_file
          JSON.parse(File.read(schema_path))
        end

        def committee_options
          @committee_options ||= { schema: Committee::Drivers::load_from_file(schema_path), prefix: root_path, validate_success_only: true }
        end

        def get_with_compatibility path, options = {}
          if Rails::VERSION::MAJOR <= 4
            get path, options[:params], options[:headers]
          else
            get path, options
          end
        end

        def post_with_compatibility path, options = {}
          if Rails::VERSION::MAJOR <= 4
            post path, options[:params], options[:headers]
          else
            post path, options
          end
        end

        def put_with_compatibility path, options = {}
          if Rails::VERSION::MAJOR <= 4
            put path, options[:params], options[:headers]
          else
            put path, options
          end
        end

        def delete_with_compatibility path, options = {}
          if Rails::VERSION::MAJOR <= 4
            delete path, options[:params], options[:headers]
          else
            delete path, options
          end
        end

        def assert_all_schema_confirm(response, status)
          expect(response).to have_http_status(status)
          assert_request_schema_confirm
          assert_response_schema_confirm
        end
      end
    end
  end
end