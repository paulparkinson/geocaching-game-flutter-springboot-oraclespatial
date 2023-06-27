package example.oracle.spatial;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import example.oracle.spatial.geojson.Feature;
import example.oracle.spatial.geojson.FeatureCollection;

import java.sql.ResultSet;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.web.bind.annotation.*;

import javax.sql.DataSource;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

@RestController
@RequestMapping("/geocache")
public class OracleGeoJSONController {

    JdbcTemplate jdbcTemplate;
    ObjectMapper mapper = new ObjectMapper();

    @Autowired
    public OracleGeoJSONController(DataSource dataSource) {
        jdbcTemplate = new JdbcTemplate(dataSource);
    }


    //Setup and admin methods...

    @GetMapping("/createDBUser")
    public String createtables(@RequestParam String userName, @RequestParam String password) throws Exception {
        jdbcTemplate.execute("create user " + userName + " identified by " + password);
        jdbcTemplate.execute("GRANT UNLIMITED TABLESPACE TO " + userName);
        jdbcTemplate.execute("GRANT create session TO " + userName);
        jdbcTemplate.execute("GRANT connect, resource TO " + userName);
        jdbcTemplate.execute("GRANT SELECT ANY TABLE TO " + userName);
        return "user created successfully: " + userName;
    }

    @GetMapping("/createTables")
    public String createTables() throws SQLException {
        String blockchantableSQL = "CREATE BLOCKCHAIN TABLE geocache_journal " +
                "(creatorname VARCHAR2(128), visitorname VARCHAR2(128), imageurl VARCHAR2(128), longitude NUMBER, latitude NUMBER)" +
                "     NO DROP UNTIL 1 DAYS IDLE" +
                "     NO DELETE UNTIL 16 DAYS AFTER INSERT" +
                "     HASHING USING \"SHA2_512\" VERSION \"v1\"";
        jdbcTemplate.execute(blockchantableSQL);
        System.out.println("OracleGeoJSONController.createtables geocache_journal table created successfully");
        jdbcTemplate.execute("CREATE TABLE geocache (geocache_doc VARCHAR2 (4000) CHECK (geocache_doc is json))");
        System.out.println("OracleGeoJSONController.createtables geocache table created successfully");
        return "createtables2 succeeded";
    }


    @GetMapping("/deleteall")
    public String deleteall() throws SQLException {
        jdbcTemplate.execute("DELETE geocache");
        return "all geocache entries deleted";
    }







    //Application/runtime methods...

    @PostMapping("/addGeoCache")
    public String addgeocache(@RequestBody FeatureCollection geodata) throws Exception {
        System.out.println("OracleGeoJSONController.addgeocache geodata.toJson():" + geodata.toJson());
        String sql = "INSERT INTO geocache (geocache_doc) VALUES (?)";
        System.out.println("OracleGeoJSONController.addgeocache:" + geodata.toJson());
        jdbcTemplate.update(sql, geodata.toJson());
        System.out.println("Inserted successfully");
        return geodata.toString();
    }

    @GetMapping("/getGeoCaches")
    public String getGeoCaches() throws Exception {
        String sql = "SELECT jt.* " +
                "FROM geocache, " +
                "     json_table(geocache_doc, '$.features[*]' " +
                "                 COLUMNS (feature CLOB FORMAT JSON PATH '$')) jt ";
        List<Feature> features = new ArrayList<>();
        jdbcTemplate.query(sql, new RowMapper() {
            @Override
            public String mapRow(ResultSet rs, int rowNum) {
                String feature;
                try {
                    feature = rs.getString("feature");
                    System.out.println("OracleGeoJSONController.mapRow feature:" + feature);
                    features.add(mapper.readValue(feature, Feature.class));
                } catch (SQLException | JsonProcessingException e) {
                    throw new RuntimeException(e);
                }
                return feature;
            }
        });
        System.out.println("getGeoCaches featureslength:" + features.size());
        String json = FeatureCollection.build(features).toJson();
        System.out.println("getGeoCaches json:" + json);
        return json;
    }



    @PostMapping("/addGeoCacheJournalEntry")
    public String addGeoCacheJournalEntry(
            @RequestParam String creatorname, @RequestParam String visitorname, @RequestParam String imageurl,
            @RequestParam double longitude, @RequestParam double latitude) throws Exception {
        System.out.println("OracleGeoJSONController.addgeocache addgeocachejournalentry");
        String sql = "INSERT INTO geocache_journal (creatorname, visitorname, imageurl, longitude, latitude) VALUES (?,?,?,?,?)";
        System.out.println("OracleGeoJSONController.addgeocachejournalentry creatorname:" + creatorname);
        jdbcTemplate.update(sql, creatorname, visitorname, imageurl, longitude, latitude);
        System.out.println("addGeoCacheJournalEntry successfully");
        return "addGeoCacheJournalEntry success";
    }

    @GetMapping("/getGeoCacheTop10")
    public String getGeoCacheTop10() throws Exception {
        String sql = "SELECT creatorname, imageurl, longitude, latitude, COUNT(*) as count FROM geocache_journal " +
                "GROUP BY creatorname, imageurl, longitude, latitude " +
                "ORDER BY count DESC " +
                "FETCH FIRST 10 ROWS ONLY";
        List<Feature> features = new ArrayList<>();
        jdbcTemplate.query(sql, new RowMapper() {
            public String mapRow(ResultSet rs, int rowNum) throws SQLException {
                String creatorname = rs.getString("creatorname");
                String imageurl = rs.getString("imageurl");
                double longitude = rs.getDouble("longitude");
                double latitude = rs.getDouble("latitude");
                int count = rs.getInt("count");
                //We don't actually return count to the front end currently but would be nice...
                System.out.println("getGeoCacheTop10 creatorname = " + creatorname + ", imageurl = " + imageurl +
                        ", longitude = " + longitude + ", latitude = " + latitude + " count=" + count);
                //visitorname is "" as we are doing counts from all visitors...
                //(see getGeoCacheJournal method for query of all journal entries including visitorname)
                Feature feature = new Feature(creatorname, "", imageurl, longitude, latitude);
                System.out.println("getGeoCacheTop10feature:" + feature);
                features.add(feature);
                return "";
            }
        });
        System.out.println("getGeoCacheTop5 featureslength:" + features.size());
        String json = FeatureCollection.build(features).toJson();
        System.out.println("getGeoCacheTop5 json:" + json);
        return json;
    }







    //Other working queries currently unused by application available for
    // extra functionality re spatial analysis, etc. as well as testing

    @GetMapping("/selectGeometryAndProperties")
    public List<String> selectGeometryAndProperties() {
        String sql = "SELECT jt.*" +
                "FROM geocache," +
                "     json_table(geocache_doc, '$.features[*]'" +
                "                 COLUMNS (geom CLOB FORMAT JSON PATH '$.geometry'," +
                "                          properties CLOB FORMAT JSON PATH '$.properties')) jt";
        List list = new ArrayList<>();
        jdbcTemplate.query(sql, new RowMapper<FeatureCollection>() {
            @Override
            public FeatureCollection mapRow(ResultSet rs, int rowNum) throws SQLException {
                try {
                    String geomJson = rs.getString("geom");
                    System.out.println("OracleGeoJSONController.mapRow geomJson:" + geomJson);
                    String propertiesJson = rs.getString("properties");
                    System.out.println("OracleGeoJSONController.mapRow propertiesJson:" + propertiesJson);
                    list.add("geomJson:" + geomJson + "propertiesJson:" + propertiesJson);
                } catch (Exception e) {
                    throw new RuntimeException(e);
                }
                return null;
            }
        });
        return list;
    }

    @GetMapping("/selectForGeometrySpatialOps")
    public void selectGeometryOnly() {
        String sql = "SELECT json_value(geocache_doc, '$.features[0].geometry' " +
                "                  RETURNING SDO_GEOMETRY " +
                "                  ERROR ON ERROR)" +
                "  FROM geocache";
        jdbcTemplate.query(sql, new RowMapper<FeatureCollection>() {
            @Override
            public FeatureCollection mapRow(ResultSet rs, int rowNum) throws SQLException {
                try {
                    Object object = rs.getObject(1);
                    // SDO_GEOMETRY, JGeometry, JGeomToGeoJson, etc. work can be conducted here
                } catch (SQLException e) {
                    throw new RuntimeException(e);
                }
                return null;
            }
        });
    }


    @GetMapping("/getGeoCacheJournal")
    public String getGeoCacheJournal() throws Exception {
        String sql = "SELECT creatorname, imageurl, longitude, latitude, visitorname FROM geocache_journal ";
        List<Feature> features = new ArrayList<>();
        jdbcTemplate.query(sql, new RowMapper() {
            public String mapRow(ResultSet rs, int rowNum) throws SQLException {
                String creatorname = rs.getString("creatorname");
                String imageurl = rs.getString("imageurl");
                double longitude = rs.getDouble("longitude");
                double latitude = rs.getDouble("latitude");
                String visitorname = rs.getString("visitorname");
                //We don't actually return count to the front end currently but would be nice...
                System.out.println("creatorname = " + creatorname + ", imageurl = " + imageurl +
                        ", longitude = " + longitude + ", latitude = " + latitude + " visitorname=" + visitorname);
                //visitorname is null as we are doing counts from all visitors...
                Feature feature = new Feature(creatorname, visitorname, imageurl, longitude, latitude);
                System.out.println("OracleGeoJSONController.mapRow feature:" + feature);
                features.add(feature);
                return "";
            }
        });
        System.out.println("getGeoCacheTop5 featureslength:" + features.size());
        String json = FeatureCollection.build(features).toJson();
        System.out.println("getGeoCacheTop5 json:" + json);
        return json;
    }


    @GetMapping("/sampledata")
    public String sampledata() {
        System.out.println("in geojson get");
        return "{" +
                "  \"type\": \"FeatureCollection\"," +
                "  \"features\": [" +
                "    {" +
                "      \"type\": \"Feature\"," +
                "      \"geometry\": {" +
                "        \"type\": \"Point\"," +
                "        \"coordinates\": [-81.5812, 28.4187]" +
                "      }," +
                "      \"properties\": {" +
                "        \"name\": \"Space Mountain\"," +
                "        \"imagelocation\": \"https://xrcloudservices.com/images/xrcloudservicesgirl.png\"" +
                "      }" +
                "    }," +
                "    {" +
                "      \"type\": \"Feature\"," +
                "      \"geometry\": {" +
                "        \"type\": \"Point\"," +
                "        \"coordinates\": [-81.5793, 28.4193]" +
                "      }," +
                "      \"properties\": {" +
                "        \"name\": \"Cinderella Castle\"," +
                "        \"imagelocation\": \"https://xrcloudservices.com/images/xrcloudserviceslogo.png\"" +
                "      }" +
                "    }" +
                "  ]" +
                "}";
    }
}





