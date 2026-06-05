local cache = {}

function add_container_name(tag, timestamp, record)
    local container_id = string.match(tag, "docker%.(.+)")
    if not container_id then
        return 1, timestamp, record
    end

    if not cache[container_id] then
        local cmd = "curl -sf --unix-socket /var/run/docker.sock http://localhost/containers/" .. container_id .. "/json"
        local handle = io.popen(cmd)
        local result = ""
        if handle then
            result = handle:read("*a")
            handle:close()
        end
        local name = string.match(result, '"Name":"/([^"]+)"')
        cache[container_id] = name or container_id:sub(1, 12)
    end

    record["container_name"] = cache[container_id]
    return 1, timestamp, record
end
