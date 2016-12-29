CREATE TYPE [Utilities].[DataGenerator] AS TABLE
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Tabl] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
PRIMARY KEY CLUSTERED  ([ID])
)
GO
