SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [Utilities].[DataGenerator] (
    @table VARCHAR(128), --single table insert
    @includeRelations BIT = NULL, --if you want to populate the related tables (relation table shoudl be filled)
    @AccountID bigint = NULL OUTPUT,
    @TableList Utilities.DataGenerator READONLY, --list of tables to populate for unit tests
    @Batch INT = NULL
    )


as

SET NOCOUNT ON 

DECLARE @stringDataCollection TABLE (name VARCHAR(128), data VARCHAR(max))

--static data
    INSERT INTO @stringDataCollection ( name, data ) --should be extend by varying text
    VALUES  ('address', 'address'),
            ('author', 'author'),
            ('email', 'email'),
            ('city', 'city'),
            ('CountryCode', 'CountryCode'),
            ('FirstName', 'FirstName'),
            ('LastName', 'LastName'),
            ('Phone', 'Phone'),
            ('PostalCode', 'PostalCode'),
            ('Street', 'Street'),
            ('Folder', 'Folder'),
            ('html', 'html'),
            ('password', 'password'),
            ('name', 'name')


    DECLARE @genlogic TABLE (type VARCHAR(128), algorithm VARCHAR(128))
    INSERT INTO @genlogic ( type, algorithm )
    VALUES  ( 'bigint', 'SELECT CAST(CHECKSUM(NEWID()) AS bigint) * CAST(100000 AS bigint) '),
              ('datetime', 'select getdate()'),
              ('date', 'select getdate()'),
              ('tinyint', 'SELECT CAST(((255 ) ) * RAND() AS TINYINT)'),
              ('int', 'SELECT CAST(((200000 ) ) * RAND() AS INT)'),
              ('varchar', 'SELECT ''1'''),
              ('float', 'select RAND(CHECKSUM(NEWID())) * 99 '),
              ('varbinary', 'select ''awwh'' '),
              ('bit', 'select 1 ')


    DECLARE @relations TABLE (tables varchar(128), related varchar(128))
    INSERT INTO @relations ( tables, related )
    --SCENARIO> account creation
    VALUES  ( 'waf_Accounts', 'bc_AccountSettings' )

    

--multi table insert
DECLARE @multiTables TABLE (tables VARCHAR(128))
INSERT INTO @multiTables ( tables )
SELECT @table

IF (SELECT COUNT(1) FROM @TableList AS tl) > 0
	INSERT INTO @multiTables ( tables )
	SELECT r.Tabl
	FROM @TableList AS r
	WHERE r.Tabl NOT IN (select mt.tables from @multiTables AS mt)

declare @tables VARCHAR(128)
        
declare Multitables cursor fast_forward
for

    select t.tables from @multiTables AS t

DECLARE @IDs TABLE (IDCol VARCHAR(128), value BIGINT, Tabl VARCHAR(128))
DELETE FROM @IDs

open Multitables
fetch next from Multitables into @tables
while @@FETCH_STATUS=0
	BEGIN
        SET @table = @tables
        DECLARE @counter INT = 0
            WHILE @counter < ISNULL(@Batch, 1)
            BEGIN
            
                --single table insert 
                DECLARE @columns TABLE (col VARCHAR(128), isIdentity BIT, datatype VARCHAR(128), length VARCHAR(128), precision VARCHAR(128), scale VARCHAR(128))
                DELETE FROM @columns
                INSERT INTO @columns ( col, isIdentity, datatype, length, precision, scale)
                SELECT c.name, c.is_identity, tp.name, c.max_length, c.precision, c.scale
                FROM sys.columns AS c
                INNER JOIN sys.tables AS t ON t.object_id = c.object_id
                INNER JOIN sys.types AS tp ON tp.user_type_id = c.user_type_id
                WHERE t.name = @table 
                    AND c.name NOT IN ('Deleted', 'Closed', 'DeletedBy') --should be null by default

                declare @select nvarchar(max) = NULL ,
                        @insert nvarchar(max) = NULL ,
                        @column VARCHAR(128),
                        @tp VARCHAR(128),
                        @logic NVARCHAR(512),
                        @LocalAccountID BIGINT,
                        @statement VARCHAR(max) = ''

                SET @select = 'values ('
                SET @insert = 'insert into dbo.' + @table + '('


                DECLARE @temp TABLE(col nvarchar(512))
                
                declare insertcursor cursor fast_forward
                for
                    select c.col 
                    FROM @columns AS c
                    WHERE c.isIdentity = 0

                OPEN insertcursor
                fetch next from insertcursor into @column
                while @@FETCH_STATUS=0
	                BEGIN
                    
                        select @tp = c.datatype FROM @columns AS c WHERE c.col = @column
                        select @logic = algorithm FROM @genlogic WHERE type = @tp
                        
                        DELETE FROM @temp
                      
                        insert INTO @temp ( col )
                        EXEC sp_executesql @logic
                        

                        --giving the same parent value in child tables
                            IF EXISTS ( --store parent
                                    SELECT 1
                                    FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS Tab
                                    INNER JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE Col ON  Col.Constraint_Name = Tab.Constraint_Name AND Col.Table_Name = Tab.Table_Name
                                    WHERE Constraint_Type = 'PRIMARY KEY'
                                    AND Col.Table_Name = @table
                                    AND Col.Column_Name = @column
                                )
                            BEGIN 
                            
                                INSERT INTO @IDs ( IDCol, value, Tabl )
                                SELECT @column, t.col, @table
                                FROM @temp AS t

                            END 

                       
                            DECLARE @IDVal BIGINT
                        
                            SELECT @IDVal = p.value from @IDs AS p WHERE p.IDCol = @column AND p.Tabl <> @table ORDER BY NEWID()
                            IF @@ROWCOUNT > 0 --found the parent in child table
                                UPDATE @temp
                                SET col = @IDVal
                            
                        SET @insert = @insert + @column + ','
        
        
                        --varchar columns
                        DECLARE @length VARCHAR(128)        
                        DECLARE @data VARCHAR(max) = ''
                        SELECT @length = length from @columns WHERE col = @column AND datatype = 'varchar'
                        IF @@ROWCOUNT > 0
                        BEGIN

                            --parse string here and get one value of chain
                            select @data = sdc.data from @stringDataCollection AS sdc WHERE @column LIKE '%'+ sdc.name  +'%'
                            IF @@ROWCOUNT > 0 --dont update default string values
                            BEGIN
                                SET @data = SUBSTRING(@data, 0, CAST(REPLACE(@length, '-1', '99999999999') AS bigint))
                                UPDATE @temp
                                SET col = @data
                            end
                        END 

                        --accountID
                        IF @column = 'AccountID' AND @LocalAccountID IS NOT NULL 
                            UPDATE @temp
                            SET col = @LocalAccountID
                        ELSE IF @column = 'AccountID' AND @LocalAccountID IS NULL 
                            SELECT @LocalAccountID = w.col FROM @temp AS w

                        declare @vb varbinary(500)

                        
                        if @tp = 'varbinary'
                            set @select = @select + ' convert(varbinary(500), ''' + (SELECT w.col FROM @temp AS w) + ''') ,'
                        else
                            set @select = @select + '''' + (SELECT w.col FROM @temp AS w) + ''','

                        SET @AccountID = @LocalAccountID
        

		                fetch next from insertcursor into @column
	                end

                CLOSE insertcursor
                deallocate insertcursor


                SET @insert = STUFF(@insert, LEN(@insert), 1, ')')
                SET @select = STUFF(@select, LEN(@select), 1, ')')



                SET @statement = @insert + @select

                EXEC (@statement)

                SET @statement = NULL
                SET @counter += 1
	        END
        
		fetch next from Multitables into @tables
	end

close Multitables
deallocate Multitables


RETURN 0

GO
