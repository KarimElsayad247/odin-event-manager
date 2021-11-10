require 'csv'
require 'erb'
require 'time'
require 'date'
require 'google/apis/civicinfo_v2'

# Cleaning the zipcode entail:
# - Making sure it's exactly 5 digits long
# - If not zip code was provided, default to '00000'
# - If a shor zipcode was provided, pad it with zeros
# Method explanation:
# - to_s coreces nil into empty string
# - rjust pads shorter codes with 0s
# - [0..4] selects the first 5 digits of the code
def clean_zipcode(zipcode)
  return zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phonenumber(number)
  # remove dashes, dots, parens, and spaces
  # @type [String]
  number = number.gsub(/[-.() ]/, '')

  if number.length == 10
    return number
  elsif number.length == 11
    return number[1..-1] if number[0] == '1'
  end

  return 'Bad number!'
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    response = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    )
    legislators = response.officials
    return legislators
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

# @type [String]
template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
regestring_hours = Hash.new(0)
regestring_weekdays = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phonenumber = clean_phonenumber row[:homephone]

  reg_date_and_time = Time.strptime(row[:regdate], '%m/%d/%y %k:%M')
  regestring_hours[reg_date_and_time.hour] += 1
  regestring_weekdays[Date::DAYNAMES[reg_date_and_time.wday]] += 1

  zipcode = clean_zipcode row[:zipcode]
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)

  # puts "#{id}, #{reg_date_and_time}, #{name}, #{zipcode}, #{phonenumber}"
end

max_hour = regestring_hours.max
max_day = regestring_weekdays.max

puts "Most people registred on #{max_day[0]} for a total of #{max_day[1]} registrations"
puts "Most people registred between #{max_hour[0]}:00-#{max_hour[0] + 1}:00 for a total of #{max_hour[1]} registrations"
