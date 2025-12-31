# Service class for generating monthly reports
# This demonstrates how to generate report attachments for notification emails
class MonthlyReportGenerator
  attr_reader :target, :month

  def initialize(target, month = Date.current.last_month)
    @target = target
    @month = month
  end

  def to_pdf
    # Generate a simple PDF report
    # In production, you would use a proper PDF library like Prawn
    content = []
    content << "MONTHLY ACTIVITY REPORT"
    content << "=" * 60
    content << ""
    content << "Report Period: #{month.strftime('%B %Y')}"
    content << "Generated: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
    content << ""
    content << "Target: #{target.class.name} ##{target.id}"
    
    if target.respond_to?(:name)
      content << "Name: #{target.name}"
    end
    
    if target.respond_to?(:email)
      content << "Email: #{target.email}"
    end
    
    content << ""
    content << "ACTIVITY SUMMARY"
    content << "-" * 60
    
    # Notification statistics
    if target.respond_to?(:notifications)
      total_notifications = target.notifications.count
      month_notifications = target.notifications.where(
        'created_at >= ? AND created_at < ?',
        month.beginning_of_month,
        month.end_of_month
      ).count rescue 0
      
      content << "Total Notifications: #{total_notifications}"
      content << "This Month: #{month_notifications}"
      
      # Opened vs unopened
      opened_count = target.notifications.opened_only.count rescue 0
      unopened_count = target.notifications.unopened_only.count rescue 0
      
      content << "Opened: #{opened_count}"
      content << "Unopened: #{unopened_count}"
    end
    
    content << ""
    content << "NOTIFICATION BREAKDOWN BY TYPE"
    content << "-" * 60
    
    if target.respond_to?(:notifications)
      # Group notifications by key
      notifications_by_key = target.notifications.group(:key).count rescue {}
      
      if notifications_by_key.any?
        notifications_by_key.each do |key, count|
          content << "#{key}: #{count}"
        end
      else
        content << "No notifications found"
      end
    end
    
    content << ""
    content << "=" * 60
    content << "End of Report"
    
    content.join("\n")
  end

  def to_csv
    # Generate CSV data
    csv_rows = []
    csv_rows << ["Month", "Total Notifications", "Opened", "Unopened"]
    
    if target.respond_to?(:notifications)
      total = target.notifications.count
      opened = target.notifications.opened_only.count rescue 0
      unopened = target.notifications.unopened_only.count rescue 0
      
      csv_rows << [
        month.strftime('%Y-%m'),
        total,
        opened,
        unopened
      ]
    else
      csv_rows << [month.strftime('%Y-%m'), 0, 0, 0]
    end
    
    # Add notification breakdown
    csv_rows << []
    csv_rows << ["Notification Type", "Count"]
    
    if target.respond_to?(:notifications)
      notifications_by_key = target.notifications.group(:key).count rescue {}
      notifications_by_key.each do |key, count|
        csv_rows << [key, count]
      end
    end
    
    csv_rows.map { |row| row.join(',') }.join("\n")
  end
end
