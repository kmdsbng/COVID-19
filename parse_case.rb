# -*- encoding: utf-8 -*-
require 'date'
require 'pp'
require 'csv'

class DailyCaseRow < Struct.new(
  :day,
  :fips,
  :admin,
  :province_state,
  :country_region,
  :last_update,
  :lat,
  :longi,
  :confirmed,
  :deaths,
  :recovered,
  :active,
  :combined_key
)

  def build_daily_case
    return DailyCase.new(day, country_region, combined_key, confirmed, deaths, recovered, active)
  end
end

class DailyCase < Struct.new(
  :day,
  :country_region,
  :combined_key,
  :confirmed,
  :deaths,
  :recovered,
  :active
)
end

def main(csv_paths)

  csv_paths.each {|csv_path|
    cases = parse_daily_cases_csv(csv_path)

    pp cases
  }

end

def parse_daily_cases_csv(csv_path)
  day = get_date(csv_path)

  cases = []
  index = 0

  CSV.foreach(csv_path) {|row|
    index += 1
    next if index == 1
    cases << DailyCaseRow.new(day, *row).build_daily_case()
  }

  return cases

end

def get_date(csv_path)
  fname = File.basename(csv_path)

  pat = /\A(\d{2})-(\d{2})-(\d{4})\./
  matched = pat.match(fname)
  if matched.nil?
    raise "invalid fname: #{fname}"
  end

  return Date.new(matched[3].to_i, matched[1].to_i, matched[2].to_i)
end

case $PROGRAM_NAME
when __FILE__
  csv_paths = ARGV
  main(csv_paths)
when /spec[^\/]*$/
  # {spec of the implementation}
end

