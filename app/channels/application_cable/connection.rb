module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_agent_id

    def connect
      self.current_agent_id = find_verified_agent
    end

    private

    def find_verified_agent
      agent_id = cookies.signed[:agent_id]
      if agent_id && Agent.find(agent_id)
        agent_id
      else
        reject_unauthorized_connection
      end
    end
  end
end
