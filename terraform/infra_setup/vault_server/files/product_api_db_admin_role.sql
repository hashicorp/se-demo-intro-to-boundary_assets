CREATE ROLE "{{username}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "{{username}}";
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO "{{username}}";