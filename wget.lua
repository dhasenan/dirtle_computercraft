local args = {...}
local url = args[1]
if not (url:sub(7) == 'http://' or url:sub(8) == 'https://') then
  url = 'http://' .. url
end
local lastSlash, _ = url:reverse():find('/')
lastSlash = #url - lastSlash + 1
local filename = url:sub(lastSlash + 1)
local response = http.get(url)
local file = io.open(filename, 'w')
file:write(response:readAll())
file:close()
response:close()
