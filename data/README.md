# Data Files

`csv/` contains normalized synthetic source tables.

`database/astercloud_fpa.sqlite` contains the same source tables plus analytical
views.

`tableau/` contains denormalized outputs generated from SQL views for easy
Tableau connection.

`manifest.json` records the seed, cutoff date, generation timestamp, and row
counts.

The data is synthetic and safe for a public portfolio. Public sources calibrate
business ranges; they do not supply any customer, employee, project, invoice, or
transaction record.

