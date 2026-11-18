function d
	dub run :dml
	if dub build $argv
		dub run :test
	end
end

function b
	dub run :dml
	dub build $argv
	mv workspace-destiny ~/etc-bin/workspace-destiny
	killall dcd-server; killall workspace-destiny
end

function r
	dub run :dml
	dub build --build=release $argv
end
