class ApplicationSerializer
    include Alba::Resource
    transform_keys :lower_camel # matches page / pageSize; decide once and keep it

    def self.timestamp(name)
       attribute(name) { |record| record.public_send(name)&.utc&.iso8601(3) }
    end
end