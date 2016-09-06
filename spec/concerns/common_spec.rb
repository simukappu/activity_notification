shared_examples_for :common do
  let(:test_class_name) { described_class.to_s.underscore.split('/').last.to_sym }
  let(:test_instance) { create(test_class_name) }

  describe "as public ActivityNotification methods with described class" do
    describe ".resolve_value" do
      before do
        allow(ActivityNotification).to receive(:get_controller).and_return('StubController')
      end

      context "with value" do
        it "returns specified value" do
          expect(ActivityNotification.resolve_value(test_instance, 1)).to eq(1)
        end
      end

      context "with Symbol" do
        it "returns specified symbol without arguments" do
          module AdditionalMethods
            def custom_method
              1
            end
          end
          test_instance.extend(AdditionalMethods)
          expect(ActivityNotification.resolve_value(test_instance, :custom_method)).to eq(1)
        end

        it "returns specified symbol with controller arguments" do
          module AdditionalMethods
            def custom_method(controller)
              controller == 'StubController' ? 1 : 0
            end
          end
          test_instance.extend(AdditionalMethods)
          expect(ActivityNotification.resolve_value(test_instance, :custom_method)).to eq(1)
        end
  
        it "returns specified symbol with controller and additional arguments" do
          module AdditionalMethods
            def custom_method(controller, key)
              controller == 'StubController' and key == 'test1.key' ? 1 : 0
            end
          end
          test_instance.extend(AdditionalMethods)
          expect(ActivityNotification.resolve_value(test_instance, :custom_method, 'test1.key')).to eq(1)
          expect(ActivityNotification.resolve_value(test_instance, :custom_method, 'test2.key')).to eq(0)
        end
      end

      context "with Proc" do
        it "returns specified lambda with context(model)  arguments" do
          test_proc = ->(model){ model == test_instance ? 1 : 0 }
          expect(ActivityNotification.resolve_value(test_instance, test_proc)).to eq(1)
        end

        it "returns specified lambda with controller and context(model)  arguments" do
          test_proc = ->(controller, model){ controller == 'StubController' and model == test_instance ? 1 : 0 }
          expect(ActivityNotification.resolve_value(test_instance, test_proc)).to eq(1)
        end
  
        it "returns specified lambda with controller, context(model) and additional arguments" do
          test_proc = ->(controller, model, key){ controller == 'StubController' and model == test_instance and key == 'test1.key' ? 1 : 0 }
          expect(ActivityNotification.resolve_value(test_instance, test_proc, 'test1.key')).to eq(1)
          expect(ActivityNotification.resolve_value(test_instance, test_proc, 'test2.key')).to eq(0)
        end
      end

      context "with Hash" do
        it "returns resolve_value for each entry of hash" do
          module AdditionalMethods
            def custom_method(controller)
              controller == 'StubController' ? 2 : 0
            end
          end
          test_instance.extend(AdditionalMethods)
          test_hash = {
            key1: 1,
            key2: :custom_method,
            key3: ->(controller, model){ 3 }
          }
          expect(ActivityNotification.resolve_value(test_instance, test_hash)).to eq({ key1: 1, key2: 2, key3: 3 })
        end
      end
    end
  end

  describe "as public instance methods" do
    describe "#resolve_value" do
      context "with value" do
        it "returns specified value" do
          expect(test_instance.resolve_value(1)).to eq(1)
        end
      end

      context "with Symbol" do
        it "returns specified symbol without arguments" do
          module AdditionalMethods
            def custom_method
              1
            end
          end
          test_instance.extend(AdditionalMethods)
          expect(test_instance.resolve_value(:custom_method)).to eq(1)
        end

        it "returns specified symbol with additional arguments" do
          module AdditionalMethods
            def custom_method(key)
              key == 'test1.key' ? 1 : 0
            end
          end
          test_instance.extend(AdditionalMethods)
          expect(test_instance.resolve_value(:custom_method, 'test1.key')).to eq(1)
          expect(test_instance.resolve_value(:custom_method, 'test2.key')).to eq(0)
        end
      end

      context "with Proc" do
        it "returns specified lambda with context(model) argument" do
          test_proc = ->(model){ model == test_instance ? 1 : 0 }
          expect(test_instance.resolve_value(test_proc)).to eq(1)
        end

        it "returns specified lambda with context(model) and additional arguments" do
          test_proc = ->(model, key){ model == test_instance and key == 'test1.key' ? 1 : 0 }
          expect(test_instance.resolve_value(test_proc, 'test1.key')).to eq(1)
          expect(test_instance.resolve_value(test_proc, 'test2.key')).to eq(0)
        end
      end

      context "with Hash" do
        it "returns resolve_value for each entry of hash" do
          module AdditionalMethods
            def custom_method
              2
            end
          end
          test_instance.extend(AdditionalMethods)
          test_hash = {
            key1: 1,
            key2: :custom_method,
            key3: ->(model){ model == test_instance ? 3 : 0 }
          }
          expect(test_instance.resolve_value(test_hash)).to eq({ key1: 1, key2: 2, key3: 3 })
        end
      end
    end
  end

end