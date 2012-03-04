class String
  def norm
    decomposed = UnicodeUtils.nfkd(self)
    downcased = UnicodeUtils.downcase(decomposed)
    downcased.split("").select { |x| x < "\u{100}" }.join
  end
end
