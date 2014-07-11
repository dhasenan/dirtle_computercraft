local args = {...}
local url = args[1]
if not (url:sub(7) == 'http://' or url:sub(8) == 'https://') then
  url = 'http://' .. url
end
local lastSlash = -1
for i in url:gfind('/') do
  lastSlash = i
end
local filename = url:substring(lastSlash)
local response = http.request(args[1])
local file = io.open(filename, 'w+')
file:write(response:readAll())
file:close()
response:close()
