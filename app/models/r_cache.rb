class RCache
  DEFAULT_EXPIRE=7.days
  
  def self.get(key)
    data.get(key)
  end

  def self.mget(*keys)
    Hash[*keys.zip(data.mget(*keys)).flatten]
  end
  
  def self.set(key, value, expire = DEFAULT_EXPIRE)
    data.set(key, value)
    data.expire(key, expire) if expire
  end

  def self.expire(key, expire = DEFAULT_EXPIRE)
    data.expire(key, expire)
  end
  
  def self.del(key)
    data.del(key)
  end
  
  def self.exists?(key)
    data.exists(key)
  end
  
  def self.keys(match)
    data.keys(match)
  end
  
  def self.data
    @@rcache ||= Redis.new
  end
end
