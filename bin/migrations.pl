#!/usr/bin/perl

use Mojo::mysql::Migrations;
 
my $migrations = Mojo::mysql::Migrations->new(mysql => $mysql);
$migrations->from_file('../migrations/tags.sql')->migrate;