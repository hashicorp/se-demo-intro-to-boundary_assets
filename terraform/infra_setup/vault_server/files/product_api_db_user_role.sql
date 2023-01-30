CREATE ROLE "{{username}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' NOINHERIT;
GRANT SELECT ON ALL TABLES IN DATABASE products TO "{{username}}";