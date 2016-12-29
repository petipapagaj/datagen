# What is Datagen?
* Datagenerator populate the specified table with test data
* Connecting data in related tables through primary key (PK field name must exist in related table)
* Generate connected data under single account
* Output the created AccountID so make the integration easier in test frameworks 

# Why the Datagen?
* There was multiple reasons to build this tool. Most importantly to provide simple dataset for unit tests.
* Also generate data by one click locally in an empty database is so useful to see not only the table definition but the collection of data the table is able to store.
* For most convinient usage stored procedure can be added to SSMS shortcuts (Environment/Keyboard/Query shortcuts). Table will be populated by selecting the table in ssms query window and hit the keys you set up

# Usage
```
EXEC Utilities.DataGenerator [ @table = { @stringvalue }, [@TableList =] { @TableList }, [@Batch = ] { @intvalue } ]
```

### Parameter description
* @table: Main table to generating data in
* @TableList: List of tables to generating data in besides of the main table
* @Batch: Volume of data

# Examples
Generate data in single table
```
EXEC Utilities.DataGenerator @table = 'lc_Chats'
```


Generate data in multiple table
```
DECLARE @TableList Utilities.DataGenerator
 
INSERT INTO @TableList ( Tabl ) VALUES ( 'lc_ChatMessages' )
 
EXEC Utilities.DataGenerator @table = 'lc_Chats', @TableList = @TableList, @Batch = 10
```

Reuse AccountID
```
DECLARE @AccountID BIGINT
 
EXEC Utilities.DataGenerator @table = 'lc_Chats', @AccountID = @AccountID OUT
 
SELECT @AccountID
```

# Backlog
intelligently generate data in string fields to have varying and meaningful data