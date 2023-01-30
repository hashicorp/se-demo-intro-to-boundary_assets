CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' NOINHERIT;
GRANT SELECT ON ALL TABLES IN DATABASE products TO "{{name}}";