# mojo_forum

Discussion and chat app for iptvcafe.com written in Perl and JavaScript


## install

	cpanm --installdeps --sudo .
	cp .env.defaults .env # change defaults 
	touch .env.local # edit as needed for passwords etc

## todo

	my $sql = "INSERT INTO foo (bar, baz) VALUES ( ?, ? )";
	my $sth = $dbh->prepare( $sql );
	$sth->execute( $bar, $baz );
