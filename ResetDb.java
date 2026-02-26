import java.sql.*;

public class ResetDb {
    public static void main(String[] args) {
        String url = "jdbc:postgresql://localhost:5432/the_guardian_v1";
        String user = "postgres";
        String pass = "ange";

        String[] tables = {
                "blocked_keywords",
                "schedule_rules",
                "content_rules",
                "parental_profiles",
                "geofence_events",
                "child_geofence_states",
                "geofences",
                "location_snapshots",
                "enforcement_events",
                "children",
                "parents"
        };

        try (Connection conn = DriverManager.getConnection(url, user, pass);
                Statement stmt = conn.createStatement()) {

            System.out.println("Connected to database. Starting reset...");

            // Disable triggers/constraints temporarily for truncate if needed,
            // but CASCADE is safer.
            for (String table : tables) {
                try {
                    stmt.execute("TRUNCATE TABLE " + table + " CASCADE");
                    System.out.println("Truncated table: " + table);
                } catch (SQLException e) {
                    System.out.println("Error truncating " + table + ": " + e.getMessage());
                }
            }

            System.out.println("Database reset complete.");

        } catch (Exception e) {
            e.printStackTrace();
            System.exit(1);
        }
    }
}
