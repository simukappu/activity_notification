require 'spec_helper'
require Rails.root.join('../../spec/concerns/models/instance_subscription_spec.rb').to_s

describe Dummy::DummySubscriber, type: :model do

  it_behaves_like :instance_subscription

end
