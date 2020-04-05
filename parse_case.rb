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
    return DailyCase.new(day, country_region, combined_key, confirmed, deaths, recovered)
  end
end

class DailyCaseRowHash < Struct.new(
  :day,
  :row_hash
)

  def check_not_nil!(value)
    if value.nil?
      pp row_hash
      raise "nil value"
    end

    return value
  end

  def country_region
    return check_not_nil!(row_hash["Country_Region"] || row_hash["Country/Region"])
  end

  def state
    return (row_hash["Province_State"] || row_hash["Province/State"]).to_s
  end

  def confirmed
    return (row_hash["Confirmed"]).to_i
  end

  def deaths
    return (row_hash["Deaths"]).to_i
  end

  def recovered
    return (row_hash["Recovered"]).to_i
  end

  def active
    return (row_hash["Active"]).to_i
  end

  def build_daily_case

    return DailyCase.new(day, country_region, state, confirmed, deaths, recovered)
  end
end

class DailyCase < Struct.new(
  :day,
  :country_region,
  :combined_key,
  :confirmed,
  :deaths,
  :recovered
)
end

class DailyCases
  def initialize
    @cases = []
  end

  def add_case(daily_case)
    @cases << daily_case
  end

  def find_by_country(country)
    selected_cases = @cases.select {|_case|
      _case.country_region == country
    }

    return CaseGroup.new(country, selected_cases)
  end
end

class CaseGroup
  attr_reader :country_region

  def initialize(country_region, cases)
    @country_region = country_region
    @cases = cases
    @day_cases_hash = {}
    @cases.each {|c|
      @day_cases_hash[c.day] ||= []
      @day_cases_hash[c.day] << c
    }
  end

  def days
    @day_cases_hash.keys.sort
  end

  def confirmed(day)
    return (@day_cases_hash[day] || []).map {|c| c.confirmed.to_i}.sum
  end

  def deaths(day)
    return (@day_cases_hash[day] || []).map {|c| c.deaths.to_i}.sum
  end

  def recovered(day)
    return (@day_cases_hash[day] || []).map {|c| c.recovered.to_i}.sum
  end

  def calc_day_offset(base_day, base_count)
    days.each {|day|
      count_of_day = confirmed(day)
      if (base_count <= count_of_day)
        return base_day - day
      end
    }

    return 0
  end
end

def main(csv_paths)

  daily_cases = DailyCases.new

  csv_paths.each {|csv_path|
    cases = parse_daily_cases_csv(csv_path)

    cases.each {|c|
      daily_cases.add_case(c)
    }
  }

  japan_cases = daily_cases.find_by_country('Japan')
  # italy_cases = daily_cases.find_by_country('Italy')
  # us_cases = daily_cases.find_by_country('US')

  countries = [
    'Italy',
    'US',
    'Spain',
    'Germany',
    'France',
    'Iran'
  ]

  country_cases_groups = countries.map {|country|
    daily_cases.find_by_country(country)
  }

  print_csv(japan_cases, country_cases_groups)

end

def print_csv(japan_cases, country_cases_groups)

  days = japan_cases.days
  today = days.last
  todays_japan_count = japan_cases.confirmed(today)
  days = days[-5..-1]
  days = (days.first..(days.first + 25))

  offsets = country_cases_groups.map {|country_cases|
    offset = country_cases.calc_day_offset(today, todays_japan_count)
    offset
  }

  puts "Day Indexes,Japan,#{country_cases_groups.map.with_index {|g, i| "#{g.country_region}(offset:#{offsets[i].to_i}days)" }.join(',')}"

  days.each {|day|
    puts "#{day.strftime('%m/%d/%y')},#{zero_to_nil(japan_cases.confirmed(day))},#{country_cases_groups.map.with_index {|g, i| "#{zero_to_nil(g.confirmed(day - offsets[i]))}" }.join(',')}"
  }
end

def zero_to_nil(value)
  if (value == 0)
    nil
  else
    value
  end
end

def parse_daily_cases_csv(csv_path)
  day = get_date(csv_path)

  cases = []
  index = 0

  CSV.foreach(csv_path, headers: true) {|row|
    cases << DailyCaseRowHash.new(day, row).build_daily_case()
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

