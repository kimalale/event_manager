require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def clean_number(phone_number)
  # Remove any non-numeric characters (e.g., dashes, spaces, parentheses)
  phone_number = phone_number.to_s.gsub(/\D/, '')

  # Check the length of the cleaned phone number
  case phone_number.length
  when 10
    # 10 digits - assume it's a good number
    phone_number
  when 11
    # 11 digits - check if the first digit is 1, and trim it if it is
    if phone_number[0] == '1'
      phone_number[1..-1]
    else
      # The first digit is not 1, so it's a bad number
      nil
    end
  else
    # Less than 10 or more than 11 digits - assume it's a bad number
    nil
  end
end

def time_targeting(info)
  registration_counts = Hash.new(0)

  # Parse the registration timestamps and count registrations for each hour
  info.each do |timestamp|
    registration_time = DateTime.strptime(timestamp[:regdate], '%m/%d/%Y %H:%M')
    hour = registration_time.hour
    registration_counts[hour] += 1
  end

  # Find the hour(s) with the highest registration counts
  max_count = registration_counts.values.max
  peak_hours = registration_counts.select { |hour, count| count == max_count }.keys

  puts "Peak registration hour(s): #{peak_hours.join(', ')}"
end

def day_of_week_targeting(info)
  registration_counts = Hash.new(0)

  # Parse the registration timestamps and count registrations for each day of the week
info.each do |timestamp|
    registration_time = DateTime.strptime(timestamp[:regdate], '%m/%d/%Y %H:%M')
    day_of_week = registration_time.wday
    registration_counts[day_of_week] += 1
  end

  # Find the day(s) of the week with the highest registration counts
  max_count = registration_counts.values.max
  peak_days = registration_counts.select { |day, count| count == max_count }.keys

  # Define a mapping for day names
  day_names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

  # Print the most popular registration day(s)
  puts "Most popular registration day(s): #{peak_days.map { |day| day_names[day] }.join(', ')}"
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  number = clean_number(row[:homephone])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)
end

puts time_targeting(contents)
print "Most people have registered on this day: #{day_of_week_targeting(contents)}"
