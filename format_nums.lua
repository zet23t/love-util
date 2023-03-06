return function(fmt,...)
	return fmt:rep(select('#',...)):format(...)
end