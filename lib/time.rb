class Time
  def Time.yesterday
    t=Time.now
    Time.at(t.to_i-86400)
  end

  def Time.seven_days_ago
    t=Time.now
    Time.at(t.to_i-(86400 * 6))
  end
end
