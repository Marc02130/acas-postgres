export PGUSER=postgres
export PGDATA=/var/lib/pgsql/15/data
export PATH=/usr/pgsql-15/bin:$PATH
db_exists(){
	DB_NAME=$1
	
	DBEXISTS=`psql <<- EOSQL
	   SELECT 1 FROM pg_database WHERE datname='$DB_NAME'
	EOSQL`
	if [[ $DBEXISTS =~ "?column? = \"1\"" ]]; then
		echo 1
	else
		echo 0
	fi
}
create_db(){
	DB_NAME=$1
	psql <<- EOSQL
	   CREATE DATABASE $DB_NAME;
	EOSQL
}
user_exists(){
	USER=$1
	USEREXISTS=`psql <<- EOSQL
		SELECT 1 FROM pg_catalog.pg_user WHERE usename = '$USER'
	EOSQL`
	if [[ $USEREXISTS =~ "?column? = \"1\"" ]]; then
		echo 1
	else
		echo 0
	fi
}
create_or_alter_user(){
	USER=$1
	PASSWORD=$2
	PASSWORD=$2
	psql $DB_NAME <<- EOSQL
	   CREATE USER $USER WITH PASSWORD '$PASSWORD'
	EOSQL
}
grant(){
	grant=$1
	psql $DB_NAME <<- EOSQL
		 grant $grant
	EOSQL
}
alter(){
	ALTER=$1
	psql $DB_NAME <<- EOSQL
		 alter $ALTER
	EOSQL
}
schema_exists(){
	SCHEMA=$1
	SCHEMAEXISTS=`psql $DB_NAME <<- EOSQL
		SELECT 1 FROM information_schema.schemata WHERE schema_name = '$SCHEMA'
	EOSQL`
	if [[ $SCHEMA =~ "?column? = \"1\"" ]]; then
		echo 1
	else
		echo 0
	fi
}
create_schema(){
	SCHEMA=$1
	AUTHORIZATION=$2
	psql $DB_NAME <<- EOSQL
	   CREATE SCHEMA $SCHEMA AUTHORIZATION $AUTHORIZATION
	EOSQL
}
run(){
	run=$1
	psql $DB_NAME <<- EOSQL
		$run
	EOSQL
}

echo "******CHECKING IF $DB_NAME DATABASE EXISTS******"
DBEXISTS=$(db_exists $DB_NAME)
if [[ $DBEXISTS == "1" ]]; then
	echo true
	echo "$DB_NAME DATABASE ALREADY EXISTS"
else
	echo false
	echo "******CREATING $DB_NAME DATABASE******"
	create_db $DB_NAME
	echo
fi

echo "******CHECKING IF $DB_USER USER EXISTS******"
USEREXISTS=$(user_exists $DB_USER)
if [[ $USEREXISTS == "1" ]]; then
	echo true
	echo "******$DB_USER USER ALREADY EXISTS******"
	OP=ALTER
else
	echo false
	OP=CREATE
fi
echo "******${OP}ing $DB_USER USER******"
create_or_alter_user $DB_USER $DB_PASSWORD $OP
grant "ALL PRIVILEGES ON DATABASE $DB_NAME to $DB_USER"
echo

echo "******CHECKING IF $ACAS_USERNAME USER EXISTS******"
USEREXISTS=$(user_exists $ACAS_USERNAME)
if [[ $USEREXISTS == "1" ]]; then
	echo true
	echo "******$ACAS_USERNAME USER ALREADY EXISTS******"
	OP=ALTER
else
	echo false
	OP=CREATE
fi
echo "******${OP}ing $ACAS_USERNAME USER******"
create_or_alter_user $ACAS_USERNAME $ACAS_PASSWORD $OP
echo

echo "******CHECKING IF $ACAS_SCHEMA SCHEMA EXISTS******"
SCHEMAEXISTS=$(schema_exists $ACAS_SCHEMA)
if [[ $SCHEMAEXISTS == "1" ]]; then
	echo true
	echo "******$ACAS_SCHEMA SCHEMA ALREADY EXISTS******"
else
	echo false
	echo "******CREATING $ACAS_SCHEMA schema******"
	create_schema $ACAS_SCHEMA $ACAS_USERNAME
	echo
fi
echo "******CREATING EXTENSIONS btree_gist and pg_trgm******"
run "CREATE EXTENSION btree_gist"
run "CREATE EXTENSION IF NOT EXISTS pg_trgm"

run "$(cat /bingo-build/bingo_install.sql)"
grant "USAGE ON SCHEMA bingo TO $ACAS_USERNAME"
grant "SELECT ON ALL TABLES IN SCHEMA bingo TO $ACAS_USERNAME"
grant "EXECUTE ON ALL FUNCTIONS IN SCHEMA bingo TO $ACAS_USERNAME"
grant "USAGE ON SCHEMA bingo TO $ACAS_USERNAME"
alter "ROLE $ACAS_USERNAME SET search_path = $ACAS_SCHEMA, bingo, public"

