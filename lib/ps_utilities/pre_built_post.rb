module PsUtilities

  module PreBuiltPost

    # this method CREATES or INSERTS a new student into PowerSchool
    # @param params (Array of Hashes) - kids with their attributes use format:
    # one kid
    # params: { students: [{dcid: 7531, student_id: 23456, email: "kid1@las.ch"}] }
    #
    # or multiple students (with ps and your school's database extensions)
    # params: { students:
    #   [ { dcid: 9753, student_id: 65432 },
    #     { dcid: 7531, student_id: 23456, email: "kid@las.ch",
    #       u_studentsuserfields: {transcriptaddrcity: "Bex"},
    #       u_students_extension: {preferredname: "Joe"}
    #     }
    #   ]
    # }
    # @return [Hash]
    # { "results": {
    #     "update_count": 2
    #     "result": [
    #       {  "client_uid": 124,
    #          "status": "SUCCESS",
    #          "action": "INSERT",
    #          "success_message" :{
    #            "id": 442,
    #            "ref": "https://server/ws/v1/student/442" }
    #        },
    #        { ... }
    #     ]
    #   }
    # }
    # @note create_students REQUIRED params are: :student_id (chosen by the school same as local_id within PS), :last_name, :first_name, :entry_date, :exit_date, :school_number, :grade_level
    # @note create_students OPTIONAL params include: :school_id, :username, :middle_name, physical address objects, mailing address objects, demographics objects, contacts objects, schedule setup objects, intial enrollment objects (disctrict and school), :contact_info, :phone, :u_studentsuserfields (powerschool defined extensions) & :u_students_extension (school defined db extensions)
    # @note create_students INVALID (ignored) params are: :id (dcid - chosen by the PS system)
    def create_students(params)
      action   = "INSERT"
      kids_api_array = build_kids_api_array(action, params)
      options  = { body: { students: { student: kids_api_array } }.to_json }
      answer = api(:post, "/ws/v1/student", options)
      return answer.parsed_response   if answer.code.to_s.eql? "200"
      return {"errorMessage"=>"#{answer.response}"}
    end
    alias_method :create_student, :create_students

    # this updates and existing student record within PowerSchool
    # (see #create_students)
    # @note update_students REQUIRED params are: **:id** (dcid) and **:student_id** (local_id)
    # @note update_students INVALID (ignored) params are: :grade_level, :entry_date, :exit_date, :school_number, :school_id
    def update_students(params)
      action = "UPDATE"
      kids_api_array = build_kids_api_array(action, params)
      return kids_api_array     if kids_api_array.empty?

      options  = { body: { students: { student: kids_api_array } }.to_json }
      answer = api(:post, "/ws/v1/student", options)
      return answer.parsed_response   if answer.code.to_s.eql? "200"
      return {"errorMessage"=>"#{answer.response}"}
    end
    alias_method :update_student, :update_students

    private

    # @param action [String] - either "INSERT" or "UPDATE"
    # @param params [Array of Hashes] - in this format -- students: [{kid_1_info}, {kid_2_info}]
    # @return [Array of Hashes] - with data like below:
    #[ {:action=>"UPDATE",
    #   :id=>7337,
    #   :client_uid=>"555807",
    #   :contact_info=>{:email=>"bassjoe@las.ch"},
    #   "_extension_data"=> {
    #     "_table_extension"=>  [
    #       { "recordFound"=>false,
    #         "name"=>"u_students_extension",
    #         "_field"=> [
    #           {"name"=>"preferredname", "type"=>"String", "value"=>"Joe"},
    #           {"name"=>"student_email", "type"=>"String", "value"=>"bassjoe@las.ch"}
    #         ]
    #       },
    #       { "recordFound"=>false,
    #         "name"=>"u_studentsuserfields",
    #         "_field"=> [
    #           {"name"=>"transcriptaddrline1", "type"=>"String", "value"=>"LAS"},
    #           {"name"=>"transcriptaddrline2", "type"=>"String", "value"=>"CP 108"},
    #           {"name"=>"transcriptaddrcity", "type"=>"String", "value"=>"Leysin"},
    #           {"name"=>"transcriptaddrzip", "type"=>"String", "value"=>"1854"},
    #           {"name"=>"transcriptaddrstate", "type"=>"String", "value"=>"Vaud"},
    #           {"name"=>"transcriptaddrcountry", "type"=>"String", "value"=>"CH"}
    #         ]
    #       }
    #     ]
    #   }
    #   { ...another_student_data... },
    #]
    # @note this is then sent to the API call with a body tag
    def build_kids_api_array(action, params)
      # ugly protection against bad data feeds - but it works
      # TODO: refactor with an elegant assertion?
      if params.nil? or not params.is_a?(Hash) or params[:students].nil? or not params[:students].is_a?(Array) or params[:students].empty? or not params[:students][0].is_a?(Hash)
        raise ArgumentError, "PARAMS format is: {students: [{kid_data1}, {kid_data2}]} - NOT OK: #{params}"
      end
      if action.nil? or not action.is_a?(String) or action.empty? or not %[INSERT UPDATE].include?(action)
        raise ArgumentError, "ACTION must be: 'INSERT' or 'UPDATE' - NOT OK: #{action}"
      end
      api_array = []
      students  =  params.dig(:students)
      students.each do |kid|
        api_array << build_kid_attributes(action, kid)
      end
      api_array
    end

    # prepare data to update student database extensions
    # @param data [Hash] - with the format: {u_students_extension: {field1: data1, field2: data2}}
    # @return [Hash] - with data like below:
    # { "name"=>"u_students_extension",
    #   "recordFound"=>false,
    #   "_field"=> [
    #     {"name"=>"preferredname", "type"=>"String", "value"=>"Joe"},
    #     {"name"=>"student_email", "type"=>"String", "value"=>"joe@las.ch"},
    #   ]
    # }
    def u_students_extension(data)
      db_extensions = { "name"=>"u_students_extension", "recordFound"=>false,
                        "_field"=> [] }
      data.each do |key, value|
        db_extensions["_field"] << {"name"=>"#{key}", "type"=>"String", "value"=>"#{value}"}
      end
      db_extensions
    end

    # prepare data to built-in database extensions
    # @param data [Hash] - with the format: {u_studentsuserfields: {field1: data1, field2: data2}}
    # @return [Hash] - with data like below:
    # { "name"=>"u_students_extension",
    #   "recordFound"=>false,
    #   "_field"=> [
    #     {"name"=>"transcriptaddrzip", "type"=>"String", "value"=>75230},
    #     {"name"=>"transcriptaddrcountry", "type"=>"String", "value"=>"United States"},
    #     {"name"=>"transcriptaddrcity", "type"=>"String", "value"=>"dallas"},
    #     {"name"=>"transcriptaddrstate", "type"=>"String", "value"=>"Texas"},
    #     {"name"=>"transcriptaddrline1", "type"=>"String", "value"=>"6138 meadow rd"}
    #   ]
    # }
    def u_studentsuserfields(data)
      db_extensions = { "name"=>"u_studentsuserfields", "recordFound"=>false,
                        "_field"=> [] }
      data.each do |key, value|
        db_extensions["_field"] << {"name"=>"#{key}", "type"=>"String", "value"=>"#{value}"}
      end
      db_extensions
    end

    # prepare an indivdual's attributes to be sent to PowerSchool
    # @param action [String, "UPDATE" or "INSERT"] - handles what powerschool should do
    # @param kid [Hash] - one kid's attributes within a hash
    # @return [Hash] - returns data in the below format:
    # Data structure to send to API (with built-in PS extensions)
    # { :action=>"UPDATE",
    #   :id=>7337,
    #   :client_uid=>"555807",
    #   :contact_info=>{:email=>"bassjoe@las.ch"},
    #   "_extension_data"=> {
    #     "_table_extension"=>  [
    #       { "recordFound"=>false,
    #         "name"=>"u_students_extension",
    #         "_field"=> [
    #           {"name"=>"preferredname", "type"=>"String", "value"=>"Joe"},
    #           {"name"=>"student_email", "type"=>"String", "value"=>"bassjoe@las.ch"}
    #         ]
    #       },
    #       { "recordFound"=>false,
    #         "name"=>"u_studentsuserfields",
    #         "_field"=> [
    #           {"name"=>"transcriptaddrline1", "type"=>"String", "value"=>"LAS"},
    #           {"name"=>"transcriptaddrline2", "type"=>"String", "value"=>"CP 108"},
    #           {"name"=>"transcriptaddrcity", "type"=>"String", "value"=>"Leysin"},
    #           {"name"=>"transcriptaddrzip", "type"=>"String", "value"=>"1854"},
    #           {"name"=>"transcriptaddrstate", "type"=>"String", "value"=>"Vaud"},
    #           {"name"=>"transcriptaddrcountry", "type"=>"String", "value"=>"CH"}
    #         ]
    #       }
    #     ]
    #   }
    def build_kid_attributes(action, kid)
      if kid.nil? or not kid.is_a?(Hash) or kid.empty?
        raise ArgumentError, "STUDENT format is: {students: [{kid_data1}, {kid_data2}]} - NOT OK: #{kid}"
      end
      if action.nil? or not action.is_a?(String) or action.empty? or not %[INSERT UPDATE].include?(action)
        raise ArgumentError, "ACTION must be: 'INSERT' or 'UPDATE' - NOT OK: #{action}"
      end
      # ALWAYS NEEDED INFO
      attribs                        = {action: action}
      attribs[:client_uid]           = kid[:student_id].to_s
      attribs[:student_username]     = kid[:username]        if kid[:username]

      # REQUIRED ON ENROLLMENT (optional later)
      attribs[:name]                 = {}
      case action
      when 'INSERT'
        # must be set on creation (INSERT)
        attribs[:local_id]           = kid[:local_id].to_i   if kid[:local_id]
        attribs[:local_id]           = kid[:student_id].to_i if kid[:student_id]
        # to create an account both first and last name must be present
        attribs[:name][:last_name]   = kid[:last_name]   if kid[:last_name] or kid[:first_name]
        attribs[:name][:first_name]  = kid[:first_name]  if kid[:last_name] or kid[:first_name]
        attribs[:name][:middle_name] = kid[:middle_name] if kid[:middle_name]
        # school_enrollment can only be SET on INSERT!
        attribs[:school_enrollment]  = {}
        if kid[:enroll_status_code]
          attribs[:school_enrollment][:enroll_status_code] = kid[:enroll_status_code]
        elsif kid[:status_code]
          attribs[:school_enrollment][:status_code]  = kid[:status_code]
        end
        attribs[:school_enrollment][:grade_level]    = kid[:grade_level]   if kid[:grade_level]
        attribs[:school_enrollment][:entry_date]     = kid[:entry_date]    if kid[:entry_date]
        attribs[:school_enrollment][:exit_date]      = kid[:exit_date]     if kid[:exit_date]
        attribs[:school_enrollment][:school_number]  = kid[:school_number] if kid[:school_number]
        attribs[:school_enrollment][:school_id]      = kid[:school_id]     if kid[:school_id]
      when 'UPDATE'
        # don't allow nil / blank name updates
        attribs[:id]                 = kid[:id] || kid[:dcid]
        attribs[:name][:last_name]   = kid[:last_name]   if kid[:last_name]
        attribs[:name][:first_name]  = kid[:first_name]  if kid[:first_name]
        attribs[:name][:middle_name] = kid[:middle_name] if kid[:middle_name]
      end

      # OPTIONAL FIELDS
      attribs[:address] = {}
      if kid[:physical_street] or kid[:physical_city] or kid[:physical_state_province] or
          kid[:physical_postal_code] or kid[:physical_grid_location]
        attribs[:address][:physical] = {}
        attribs[:address][:physical][:street] = kid[:physical_street]      if kid[:physical_street]
        attribs[:address][:physical][:city]   = kid[:physical_city]        if kid[:physical_city]
        attribs[:address][:physical][:state_province] = kid[:physical_state]    if kid[:physical_state]
        attribs[:address][:physical][:postal_code]    = kid[:physical_postal_code] if kid[:physical_postal_code]
        attribs[:address][:physical][:grid_location]  = kid[:physical_grid_location] if kid[:physical_grid_location]
      end
      if kid[:mailing_street] or kid[:mailing_city] or kid[:mailing_state_province] or
          kid[:mailing_postal_code] or kid[:mailing_grid_location]
        attribs[:address][:mailing] = {}
        attribs[:address][:mailing][:street] = kid[:mailing_street]      if kid[:mailing_street]
        attribs[:address][:mailing][:city]   = kid[:mailing_city]        if kid[:mailing_city]
        attribs[:address][:mailing][:state_province] = kid[:mailing_state]    if kid[:mailing_state]
        attribs[:address][:mailing][:postal_code]    = kid[:mailing_postal_code] if kid[:mailing_postal_code]
        attribs[:address][:mailing][:grid_location]  = kid[:mailing_grid_location] if kid[:mailing_grid_location]
      end
      attribs[:contact] = {}
      if kid[:emergency_phone1] && kid[:emergency_contact_name1]
        attribs[:contact][:emergency_phone1]        = kid[:emergency_phone1]
        attribs[:contact][:emergency_contact_name1] = kid[:emergency_contact_name1]
      end
      if kid[:emergency_phone2] && kid[:emergency_contact_name2]
        attribs[:contact][:emergency_phone2]        = kid[:emergency_phone2]
        attribs[:contact][:emergency_contact_name2] = kid[:emergency_contact_name2]
      end
      if kid[:doctor_phone] && kid[:doctor_name]
        attribs[:contact][:doctor_phone]  = kid[:doctor_phone]
        attribs[:contact][:doctor_name]   = kid[:doctor_name]
      end
      attribs[:contact][:guardian_email]  = kid[:guardian_email]   if kid[:guardian_email]
      attribs[:contact][:guardian_fax]    = kid[:guardian_fax]     if kid[:guardian_fax]
      attribs[:contact][:mother]          = kid[:mother]           if kid[:mother]
      attribs[:contact][:father]          = kid[:father]           if kid[:father]
      attribs[:contact] = nil            if attribs[:contact].empty?
      #
      attribs[:demographics] = {}
      attribs[:demographics][:gender]     = kid[:gender]           if kid[:gender]
      attribs[:demographics][:birth_date] = kid[:birth_date]       if kid[:birth_date]
      attribs[:demographics][:projected_graduation_year] = kid[:projected_graduation_year] if kid[:projected_graduation_year]
      attribs[:demographics][:ssn]        = kid[:ssn]              if kid[:ssn]
      #
      attribs[:schedule_setup] = {}
      attribs[:schedule_setup][:home_room]   = kid[:home_room]     if kid[:home_room]
      attribs[:schedule_setup][:next_school] = kid[:next_school]   if kid[:next_school]
      attribs[:schedule_setup][:sched_next_year_grade] = kid[:sched_next_year_grade] if kid[:sched_next_year_grade]
      #
      attribs[:initial_enrollment] = {}
      attribs[:initial_enrollment][:school_entry_date]          = kid[:school_entry_date]          if kid[:school_entry_date]
      attribs[:initial_enrollment][:school_entry_grade_level]   = kid[:school_entry_grade_level]   if kid[:school_entry_grade_level]
      attribs[:initial_enrollment][:district_entry_date]        = kid[:district_entry_date]        if kid[:district_entry_date]
      attribs[:initial_enrollment][:district_entry_grade_level] = kid[:district_entry_grade_level] if kid[:district_entry_grade_level]
      #
      attribs[:contact_info]     = {email: kid[:email]}                  if kid[:email]
      attribs[:phone]            = {main: {number: kid[:mobile]}}        if kid[:mobile]

      # Update LAS Database Extensions as needed
      attribs["_extension_data"] = { "_table_extension" => [] }
      # built-in extensions by PowerSchool
      attribs["_extension_data"]["_table_extension"] << u_studentsuserfields(kid[:u_studentsuserfields]) if kid[:u_studentsuserfields]
      # school defined database extensions
      attribs["_extension_data"]["_table_extension"] << u_students_extension(kid[:u_students_extension]) if kid[:u_students_extension]
      # if no extension data present make it empty
      attribs["_extension_data"] = {}                if attribs["_extension_data"]["_table_extension"].empty?

      # remove, nils, empty strings and empty hashes
      answer = attribs.reject { |k,v| v.nil? || v.to_s.empty? || v.to_s.eql?("{}")}
      # pp "kid-attributes"
      # pp answer
      return answer
    end

  end
end
