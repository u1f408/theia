# frozen_string_literal: true

class Novel < Sequel::Model
  many_to_one :user

  one_to_many :goals
  one_to_many :wordcounts

  def wordcount_at(time)
    wc = wordcounts_dataset
         .where { as_at < time }
         .reverse(:as_at)
         .select(:words)
         .first
    wc ? wc[:words] : 0
  end

  def todaycount
    count = Preparation::Todaycount[id: id]
    (count && count[:words]) || 0
  end

  def wordcount
    wordcount_at Time.now
  end

  def wordcount=(wc)
    add_wordcount Wordcount.create(words: wc)
  end
end