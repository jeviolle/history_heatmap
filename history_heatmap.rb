#!/usr/bin/env ruby

require 'sqlite3'
require 'inifile'
require 'optparse'
require_relative 'lib/time'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: history_heatmap.rb [options]"
  opts.on("-t", "--today", "From today's browser history") do |v|
    options[:today] = 'Today'
  end
  opts.on("-y", "--yesterday", "From yesterday's browser history") do |v|
    options[:yesterday] = 'Yesterday'
  end
# TODO
#  opts.on("-w", "--week", "From the last 7 days of browser history") do |v|
#    options[:week] = 'Last 7 days'
#  end
#  opts.on("-m", "--month", "From this month's browser history") do |v|
#    options[:month] = 'This month'
#  end
end.parse!

if options.length > 1
  puts "ERROR: Only one option allowed at a time"
  exit 2
elsif options.length < 1
  puts "ERROR: No options specified"
  exit 2
end

def get_profiles(profiles_ini)
  profiles = Hash.new
  
  ini = IniFile.new( :filename => profiles_ini )
  ini.sections.grep(/Profile/).each do |profile|
    if ini[profile]['IsRelative'].eql?("1")
      profiles[ini[profile]['Name']]=File.dirname(profiles_ini) + '/' + ini[profile]['Path']
    else
      profiles[ini[profile]['Name']]=ini[profile]['Path']
    end
  end

  return profiles 
end

def get_private_dir
  if RUBY_PLATFORM =~ /darwin/
    if Dir.exists?(ENV['HOME'] + '/Library/Application Support/Firefox')
      return ENV['HOME'] + '/Library/Application Support/Firefox'
    end  
  end
end

def get_history(profile_dir,date_range)

  query = 'SELECT moz_places.url,(moz_historyvisits.visit_date/1000000)
FROM moz_historyvisits,moz_places WHERE moz_places.id=moz_historyvisits.place_id'

  # get generate sql based on date_range
  case date_range
    when /today/
      query = query + " and date(moz_historyvisits.visit_date/1000000,\'unixepoch\',\'localtime\')=\'#{Time.now.strftime("%Y-%m-%d")}\'"
      time_format = "%H"
    when /yesterday/
      query = query + " and date(moz_historyvisits.visit_date/1000000,\'unixepoch\',\'localtime\')=\'#{Time.yesterday.strftime("%Y-%m-%d")}\'"
      time_format = "%H"
    when /week/
      query = query + " and (moz_historyvisits.visit_date/1000000) >= #{Time.seven_days_ago.to_i}"
      time_format = "%Y-%m-%d"
    when /month/
      query = query + " and date(moz_historyvisits.visit_date/1000000,\'unixepoch\') like \'#{Time.now.strftime("%Y-%m-")}%\'"
      time_format = "%Y-%m-%d"
    #when 'Past 5 months'
    #when 'Older than 6 months'
  end

  results = Hash.new
  dbh = SQLite3::Database.new("#{profile_dir}/places.sqlite") 

  dbh.execute(query) do |row|
      # 0 = url
      # 1 = timestamp
      str_row = row.to_s

      # extract the site and timestamp
      site = $1 if str_row.split(',')[0].match(/http[s]?:\/\/(.+?)\//)
      timestamp = str_row.split(', ')[1].gsub(/\[|\]|\"| /,'')

      if results[site].nil? and site
        results[site] = { 'count' => 1, 'timestamp' => [Time.at(timestamp.to_i).strftime(time_format)] }
      end

      #results[site]['count'] = results[site]['count'] + 1
      results[site]['timestamp'].push(Time.at(timestamp.to_i).strftime(time_format))
  end

  return results

end

def write_history_results(profile,date_range,visit_history)
  open("/tmp/#{profile}_#{date_range}_history_results.csv", "w") { |f|
    case date_range 
      when /(today|yesterday)/

        hours = (0..23).map {|i| sprintf("%02d", i)}
        f.puts "Site,#{hours.join(',')}"

        visit_history.each_key do |key|
          f.puts "#{key},#{(hours.sort.map {|i| visit_history[key]['timestamp'].count(i)}).join(',')}"
        end

      when /week/ # TODO
      when /month/  # TODO
    end
  }
end

## BEGIN
get_profiles(get_private_dir + '/profiles.ini').each do |name, path|
   date_range = options.flatten[0]
   prefix = "#{name}_#{date_range}"

   $stderr.puts "Processing profile: #{name} ... /tmp/#{prefix}_history_results.csv"
   write_history_results(name,date_range,get_history(path,date_range))

   # create temp heatmap script for R from template
   open("/tmp/#{prefix}_history_results.R", 'w') { |f|
     File.open("template.R",'r').each_line do |t|
       f.puts t.to_s.gsub("RESULTS","/tmp/#{prefix}_history_results.csv")
     end
   }

   # generate the heatmap using R
   `R --vanilla < /tmp/#{prefix}_history_results.R` 
end
