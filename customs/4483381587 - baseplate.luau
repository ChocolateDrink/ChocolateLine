local module = {}

function module.test1()
	return print('test 1')
end

function module.test2(num, str)
	return print(tonumber(num), tostring(str))
end

function module.test3(...)
	return print(...)
end

(function()
	print('on load!')
end)()

return module
