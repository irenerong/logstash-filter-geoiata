require 'spec_helper'
require "logstash/filters/geoiata"

describe LogStash::Filters::Geoiata do
  describe "find location with iata code" do
    let(:config) do <<-CONFIG
      filter {
        geoiata {
          source => "code"
	  target => "geoip"
        }
      }
    CONFIG
    end

    sample("code" => "NCE") do
      expect(subject).to include("geoip")
      expect(subject['geoip']['city_name']).to eq('Nice')
    end
  end
end
