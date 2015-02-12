module Apple
  module DeviceEnrollmentProgram

    class Device

      attr_reader :serial_number, :model, :profile_status

      def initialize(serial_number:, attributes: {})
        @serial_number = serial_number
        update attributes
      end

      def update(attributes = {})
        @model = attributes['model'] if attributes['model']
        @description = attributes['description'] if attributes['description']
        @color = attributes['color'] if attributes['color']
        @asset_tag = attributes['asset_tag'] if attributes['asset_tag']
        @profile_status = attributes['profile_status'] if attributes['profile_status']
        @profile_uuid = attributes['profile_uuid'] if attributes['profile_uuid']
        @profile_assign_time = DateTime.parse(attributes['profile_assign_time']) if attributes['profile_assign_time']
        @device_assigned_date = DateTime.parse(attributes['device_assigned_date']) if attributes['device_assigned_date']
        @device_assigned_by = attributes['device_assigned_by'] if attributes['device_assigned_by']
      end

      def <=>(other_device)
        serial_number <=> other_device.serial_number
      end

      def empty_profile_status?
        profile_status == 'empty'
      end

    end
  end
end
