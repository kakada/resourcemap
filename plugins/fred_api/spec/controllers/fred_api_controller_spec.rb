require 'spec_helper'

describe FredApiController do
  include Devise::TestHelpers

  let!(:user) { User.make }
  let!(:collection) { user.create_collection(Collection.make) }
  let!(:layer) { collection.layers.make }

  # We test only the field types supported by FRED API
  # Id fields are tested below
  let!(:text) { layer.fields.make :code => 'manager', :kind => 'text' }
  let!(:numeric) { layer.fields.make :code => 'numBeds', :kind => 'numeric' }
  let!(:select_many) { layer.fields.make :code => 'services', :kind => 'select_many', :config => {'options' => [{'id' => 1, 'code' => 'XR', 'label' => 'X-ray'}, {'id' => 2, 'code' => 'OBG', 'label' => 'Gynecology'}]} }
  let!(:date) { layer.fields.make :code => 'inagurationDay', :kind => 'date' }

  before(:each) { sign_in user }

  describe "GET facility" do

    let!(:site) { collection.sites.make }

    let!(:site_with_properties) { collection.sites.make :properties => {
      text.es_code => "Mrs. Liz",
      numeric.es_code => 55,
      select_many.es_code => [1, 2],
      date.es_code => "2012-10-24T00:00:00Z",
    }}

    it 'should get default fields' do
      get :show_facility, id: site.id, format: 'json', collection_id: collection.id
      response.should be_ok
      response.content_type.should eq 'application/json'

      json = JSON.parse response.body
      json["name"].should eq(site.name)
      json["id"].should eq("#{site.id}")
      json["coordinates"][0].should eq(site.lng)
      json["coordinates"][1].should eq(site.lat)
      json["active"].should eq(true)
      json["url"].should eq("http://test.host/plugin/fred_api/collections/#{collection.id}/fred_api/v1/facilities/#{site.id}.json")

    end

    it 'should get extended properties' do
      get :show_facility, id: site_with_properties.id, format: 'json', collection_id: collection.id

      json = JSON.parse response.body
      json["properties"].length.should eq(4)
      json["properties"]['manager'].should eq("Mrs. Liz")
      json["properties"]['numBeds'].should eq(55)
      json["properties"]['services'].should eq(['XR', 'OBG'])
      json["properties"]['inagurationDay'].should eq("2012-10-24T00:00:00Z")
    end

    it "should convert time in different timezone to UTC" do
      stub_time Time.iso8601("2013-02-04T20:25:27-03:00").to_s
      site2 = collection.sites.make name: 'Arg Site'
      get :show_facility, id: site2.id, format: 'json', collection_id: collection.id
      json = JSON.parse response.body
      json["createdAt"].should eq("2013-02-04T23:25:27Z")
    end
  end

  describe "query list of facilities" do
    let!(:site1) { collection.sites.make name: 'Site A', properties:{ date.es_code => "2012-10-24T00:00:00Z"} }
    let!(:site2) { collection.sites.make name: 'Site B', properties:{ date.es_code => "2012-10-25T00:00:00Z"} }

    it 'should get the full list of facilities' do
      get :facilities, format: 'json', collection_id: collection.id
      response.should be_success
      response.content_type.should eq 'application/json'

      json = (JSON.parse response.body)["facilities"]
      json.length.should eq(2)
    end

    it 'should sort the list of facilities by name asc' do
      get :facilities, format: 'json', sortAsc: 'name', collection_id: collection.id

      json = (JSON.parse response.body)["facilities"]
      json.length.should eq(2)
      json[0]["name"].should eq(site1.name)
      json[1]["name"].should eq(site2.name)
    end

    it 'should sort the list of facilities by name desc' do
      get :facilities, format: 'json', sortDesc: 'name', collection_id: collection.id

      json = (JSON.parse response.body)["facilities"]
      json.length.should eq(2)
      json[0]["name"].should eq(site2.name)
      json[1]["name"].should eq(site1.name)
    end

    it 'should sort the list of facilities by property date' do
      get :facilities, format: 'json', sortDesc: 'inagurationDay', collection_id: collection.id

      json = (JSON.parse response.body)["facilities"]
      json.length.should eq(2)
      json[0]["name"].should eq(site2.name)
      json[1]["name"].should eq(site1.name)
    end

    it 'should limit the number of facilities returned and the offset for the query' do
      get :facilities, format: 'json', limit: 1, collection_id: collection.id
      json = (JSON.parse response.body)["facilities"]
      json.length.should eq(1)
      json[0]["name"].should eq(site1.name)
      get :facilities, format: 'json', limit: 1, offset: 1, collection_id: collection.id
      json = (JSON.parse response.body)["facilities"]
      json.length.should eq(1)
      json[0]["name"].should eq(site2.name)
    end

    it 'should select only default fields' do
      get :facilities, format: 'json', fields: "name,id", collection_id: collection.id
      json = (JSON.parse response.body)["facilities"]
      json.length.should eq(2)
      json[0].length.should eq(2)
      json[0]['name'].should eq(site1.name)
      json[0]['id'].should eq(site1.id.to_s)

      json[1].length.should eq(2)
      json[1]['name'].should eq(site2.name)
      json[1]['id'].should eq(site2.id.to_s)
    end

    it 'should select default and custom fields' do
      get :facilities, format: 'json', fields: "name,properties:inagurationDay", collection_id: collection.id
      json = (JSON.parse response.body)["facilities"]
      json.length.should eq(2)
      json[0].length.should eq(2)
      json[0]['name'].should eq(site1.name)
      json[0]['properties']['inagurationDay'].should eq("2012-10-24T00:00:00Z")

      json[1].length.should eq(2)
      json[1]['name'].should eq(site2.name)
      json[1]['properties']['inagurationDay'].should eq("2012-10-25T00:00:00Z")
    end

   it 'should return all fields (default and custom) when parameter allProperties is set' do
      get :facilities, format: 'json', allProperties: true, collection_id: collection.id
      json = (JSON.parse response.body)["facilities"]
      json.length.should eq(2)
      json[0]['properties'].length.should eq(1)
      json[1]['properties'].length.should eq(1)
    end

    describe "Filtering Facilities" do

      it "should filter by name" do
        get :facilities, format: 'json', name: site1.name, collection_id: collection.id
        json = (JSON.parse response.body)["facilities"]
        json.length.should eq(1)
        json[0]['name'].should eq(site1.name)
      end

      it "should filter by id" do
        get :facilities, format: 'json', id: site1.id, collection_id: collection.id
        json = (JSON.parse response.body)["facilities"]
        json.length.should eq(1)
        json[0]['id'].should eq(site1.id.to_s)
      end

      it "should filter by coordinates" do
        get :facilities, format: 'json', coordinates: [site1.lng.to_f, site1.lat.to_f], collection_id: collection.id
        json = (JSON.parse response.body)["facilities"]
        json.length.should eq(1)
        json[0]['id'].should eq(site1.id.to_s)
      end

      it "should filter by updated_at" do
        #this query has a 2 seconds bound
        sleep 3
        site3 = collection.sites.make name: 'Site C'
        iso_updated_at = Time.zone.parse(site3.updated_at.to_s).utc.iso8601
        get :facilities, format: 'json', updatedAt: iso_updated_at, collection_id: collection.id
        json = (JSON.parse response.body)["facilities"]
        json.length.should eq(1)
        json[0]['id'].should eq(site3.id.to_s)
      end

      it "should filter by created_at" do
        #this query has a 2 seconds bound
        sleep 3
        site3 = collection.sites.make name: 'Site C'
        iso_created_at = Time.zone.parse(site3.created_at.to_s).utc.iso8601
        get :facilities, format: 'json', createdAt: iso_created_at, collection_id: collection.id
        json = (JSON.parse response.body)["facilities"]
        json.length.should eq(1)
        json[0]['id'].should eq(site3.id.to_s)
      end

      it "should filter by active" do
        #All ResourceMap facilities are active, because ResourceMap does not implement logical deletion yet
        get :facilities, format: 'json', active: 'false', collection_id: collection.id
        json = (JSON.parse response.body)["facilities"]
        json.length.should eq(0)
      end

      it "should filter by updated since" do
        sleep 3
        iso_before_update = Time.zone.now.utc.iso8601
        site1.name = "Site A New"
        site1.save!
        get :facilities, format: 'json', updatedSince: iso_before_update, collection_id: collection.id
        json = (JSON.parse response.body)["facilities"]
        json.length.should eq(1)
        json[0]['id'].should eq(site1.id.to_s)
      end

      it "should filter by updated since with miliseconds" do
        sleep 3
        iso_before_update = Time.zone.now.utc.iso8601 5
        site1.name = "Site A New"
        site1.save!
        get :facilities, format: 'json', updatedSince: iso_before_update, collection_id: collection.id
        json = (JSON.parse response.body)["facilities"]
        json.length.should eq(1)
        json[0]['id'].should eq(site1.id.to_s)
      end

      it "should filter by updated since with arbitrary updated_at velues" do
        site1.destroy
        site2.destroy
        stub_time Time.iso8601("2013-02-04T21:25:27Z").to_s
        site3 = collection.sites.make name: 'Site C'
        stub_time Time.iso8601("2013-02-04T22:55:53Z").to_s
        site4 = collection.sites.make name: 'Site D'
        stub_time Time.iso8601("2013-02-04T22:55:59Z").to_s
        site5 = collection.sites.make name: 'Site E'
        get :facilities, format: 'json', updatedSince: "2013-02-04T22:55:53Z", collection_id: collection.id
        json = (JSON.parse response.body)["facilities"]
        json.length.should eq(2)
        json[0]['id'].should eq(site4.id.to_s)
        json[1]['id'].should eq(site5.id.to_s)
      end

    end

  end

  describe "delete facility" do
    it "should delete facility" do
      site3 = collection.sites.make name: 'Site C'
      delete :delete_facility, id: site3.id, collection_id: collection.id
      response.body.should eq("http://test.host/plugin/fred_api/collections/#{collection.id}/fred_api/v1/facilities/#{site3.id}.json")
      sites = Site.find_by_name 'Site C'
      sites.should be(nil)
    end
  end

  describe "http status codes" do
    let!(:site) { collection.sites.make }
    it "should return 200 in a valid request" do
      get :show_facility, id: site.id, format: 'json', collection_id: collection.id
      response.should be_success
    end

    it "should return 401 if the user is not signed_in" do
      sign_out user
      get :show_facility, id: site.id, format: 'json', collection_id: collection.id
      response.status.should eq(401)
    end

    it "should return 401 if the user is not signed_in" do
      sign_out user
      get :show_facility, id: site.id, format: 'json', collection_id: collection.id
      response.status.should eq(401)
    end

    it "should return 403 if user is do not have permission to access the site" do
      user2 = User.make
      sign_out user
      sign_in user2
      get :show_facility, id: site.id, format: 'json', collection_id: collection.id
      response.status.should eq(403)
    end

    it "should return 403 if user is do not have permission to access the collection" do
      collection2 = Collection.make
      get :show_facility, id: site.id, format: 'json', collection_id: collection2.id
      response.status.should eq(403)
    end

    it "should return 409 if the site do not belong to the collection" do
      collection2 = Collection.make
      user.create_collection(collection2)
      get :show_facility, id: site.id, format: 'json', collection_id: collection2.id
      response.status.should eq(409)
    end

    it "should return 404 if the requested site does not exist" do
      get :show_facility, id: 12355259, format: 'json', collection_id: collection.id
      response.status.should eq(404)
    end

    it "should return 422 if a non existing field is included in the query" do
      get :facilities, format: 'json', invalid: "option", collection_id: collection.id
      response.status.should eq(422)
    end
  end

  describe "External Facility Identifiers" do
    let!(:moh_id) {layer.fields.make :code => 'moh-id', :kind => 'identifier', :config => {"context" => "MOH", "agency" => "DHIS"} }

     let!(:site_with_metadata) { collection.sites.make :properties => {
        moh_id.es_code => "53adf",
        date.es_code => "2012-10-24T00:00:00Z",
      }}

    it "should return identifiers in single facility query" do
      get :show_facility, id: site_with_metadata.id, format: 'json', collection_id: collection.id
      json = JSON.parse response.body

      json["name"].should eq(site_with_metadata.name)
      json["id"].should eq("#{site_with_metadata.id}")
      json["identifiers"].length.should eq(1)
      json["identifiers"][0].should eq({"context" => "MOH", "agency" => "DHIS", "id"=> "53adf"})
    end

    it 'should filter by identifier', focus: true do
      get :facilities, format: 'json',  collection_id: collection.id, "identifiers.id" => "53adf"
      json = (JSON.parse response.body)["facilities"]
      json.length.should eq(1)
      json[0]['id'].should eq("#{site_with_metadata.id}")
    end

    it 'should filter by identifier and agency' do
      get :facilities, format: 'json',  collection_id: collection.id, "identifiers.agency" => "DHIS", "identifiers.id" => "53adf"
      json = (JSON.parse response.body)["facilities"]
      json.length.should eq(1)
      json[0]['id'].should eq("#{site_with_metadata.id}")
    end

    it 'should filter by identifier and context' do
      get :facilities, format: 'json',  collection_id: collection.id, "identifiers.context" => "MOH", "identifiers.id" => "53adf"
      json = (JSON.parse response.body)["facilities"]
      json.length.should eq(1)
      json[0]['id'].should eq("#{site_with_metadata.id}")
    end

    it 'should filter by identifier, context and agency' do
      get :facilities, format: 'json',  collection_id: collection.id, "identifiers.context" => "MOH", "identifiers.id" => "53adf", "identifiers.agency" => "DHIS"
      json = (JSON.parse response.body)["facilities"]
      json.length.should eq(1)
      json[0]['id'].should eq("#{site_with_metadata.id}")
    end

    it 'sholud return an empty list if the id does not match' do get :facilities, format: 'json',  collection_id: collection.id, "identifiers.context" => "MOH", "identifiers.id" => "invalid", "identifiers.agency" => "DHIS"
      json = (JSON.parse response.body)["facilities"]
      json.length.should eq(0)
    end

    it 'sholud return an empty list if the context does not match any identifier' do get :facilities, format: 'json',  collection_id: collection.id, "identifiers.context" => "invalid", "identifiers.id" => "53adf", "identifiers.agency" => "DHIS"
      json = (JSON.parse response.body)["facilities"]
      json.length.should eq(0)
    end

    it 'sholud return an empty list if the agency does not match any identifier' do get :facilities, format: 'json',  collection_id: collection.id, "identifiers.context" => "MOH", "identifiers.id" => "53adf", "identifiers.agency" => "invalid"
      json = (JSON.parse response.body)["facilities"]
      json.length.should eq(0)
    end

  end

end