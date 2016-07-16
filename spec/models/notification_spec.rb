RSpec.describe ActivityNotification::Notification, type: :model do

  # --- Validation ---
  describe "with validation" do
    before { @notification = build(:notification) }

    it "is valid with target, notifiable and key" do
      expect(@notification).to be_valid
    end
  
    it "is invalid with blank target" do
      @notification.target = nil
      expect(@notification).to be_invalid
      expect(@notification.errors[:target].size).to eq(1)
    end
  
    it "is invalid with blank notifiable" do
      @notification.notifiable = nil
      expect(@notification).to be_invalid
      expect(@notification.errors[:notifiable].size).to eq(1)
    end
  
    it "is invalid with blank key" do
      @notification.key = nil
      expect(@notification).to be_invalid
      expect(@notification.errors[:key].size).to eq(1)
    end
  end

  describe "with association" do
    it "belongs to notification as group_owner" do
      group_owner  = create(:notification, group_owner: nil)
      group_member = create(:notification, group_owner: group_owner)
      expect(group_member.group_owner).to eq(group_owner)
    end
  end

end
