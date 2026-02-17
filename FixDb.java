import java.sql.*;

public class FixDb {
    public static void main(String[] args) {
        String url = "jdbc:postgresql://localhost:5432/the_guardian_v1";
        String user = "postgres";
        String pass = "ange";

        try (Connection conn = DriverManager.getConnection(url, user, pass);
                Statement stmt = conn.createStatement()) {

            System.out.println("Connected to database.");

            // Check if column exists to avoid error if run multiple times (though ADD
            // COLUMN would fail anyway)
            // But catching exception is easier.
            try {
                stmt.execute("ALTER TABLE parents ADD COLUMN verified boolean DEFAULT false NOT NULL");
                System.out.println("Successfully added 'verified' column.");
            } catch (SQLException e) {
                if (e.getMessage().contains("already exists")) {
                    System.out.println("Column 'verified' already exists. Trying to ensure it's correct...");
                    // Optional: could try to update defaults if needed, but likely fine.
                } else {
                    System.out.println("Error adding column: " + e.getMessage());
                    // If the error is about NULL values, we might need to handle it, but DEFAULT
                    // false handles it.
                    // If the column exists but is in a bad state, we might need manual help.
                    e.printStackTrace();
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
            System.exit(1);
        }
    }
}
