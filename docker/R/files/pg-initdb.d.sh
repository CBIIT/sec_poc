echo "RUNNING pg-initdb.d.sh"
su postgres
psql postgres -c "DROP USER IF EXISTS sec"
psql postgres -c "create user sec with password 'sec'"
psql postgres -c "create database sec"
psql sec -c "grant all privileges on database sec to sec"
psql sec -c "GRANT USAGE ON SCHEMA public TO  sec"
psql sec -c "GRANT CREATE ON SCHEMA public TO sec"

psql postgres -c "create user --superuser postgres"
psql postgres -c "create role sec_read"
echo "RAN pg-initdb.d.sh"