require 'spec_helper'

describe Telemetry::MembershipsCollector do

  it "counts sites grouped by collection_id" do
    u1 = User.make
    u2 = User.make

    c1 = Collection.make
    c2 = Collection.make

    period = InsteddTelemetry::Period.current

    Membership.make user: u1, collection: c1
    Membership.make user: u1, collection: c2
    
    Membership.make user: u2, collection: c1

    expect(stats(period)).to eq({
      "counters" => [
        {
          "metric"  => "memberships",
          "key"   => { "collection_id" => c1.id },
          "value" => 2
        },
        {
          "metric"  => "memberships",
          "key"   => { "collection_id" => c2.id },
          "value" => 1
        }
      ]
    })
  end

  it "takes into account current period" do
    Timecop.freeze(Time.now)
    c = Collection.make
    3.times { Membership.make user: User.make, collection: c }
    p0 = InsteddTelemetry::Period.current

    Timecop.freeze(Time.now + InsteddTelemetry::Period.span)
    10.times { Membership.make user: User.make, collection: c }
    p1 = InsteddTelemetry::Period.current

    expect(stats(p0)).to eq({
      "counters" => [
        {
          "metric"  => "memberships",
          "key"   => { "collection_id" => c.id },
          "value" => 3
        }
      ]
    })

    expect(stats(p1)).to eq({
      "counters" => [
        {
          "metric"  => "memberships",
          "key"   => { "collection_id" => c.id },
          "value" => 13
        }
      ]
    })
  end

  def stats(period)
    Telemetry::MembershipsCollector.collect_stats(period)
  end

end
