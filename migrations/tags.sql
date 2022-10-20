-- 1 up
create table tags (message text);
insert into messages values ('I ♥ Mojolicious!');
delimiter //
create procedure mojo_test()
begin
  select text from messages;
end
//
-- 1 down
drop table messages;
drop procedure mojo_test;
 
-- 2 up (...you can comment freely here...)
create table stuff (whatever int);
-- 2 down
drop table stuff;