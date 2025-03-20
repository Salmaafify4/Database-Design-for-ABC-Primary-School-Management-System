-- Database Schema 

-- Strong Entities & Relationships tables 
-- ON DELETE CASCADE ---> Deletes child records automatically.

create table AcademicYear(
	AcademicYearID INT Primary key ,
	YearStart INT Not Null ,
	YearEnd INT Not NUll
);
create table Instructor (
	InstructorID INT Primary Key ,
	Code varchar(20) UNIQUE Not Null,
	InstructorName varchar(100) Not Null,
	Email varchar(100) Not Null, 
	Mobile_Number varchar(20) ,
	IsDeleted Bit DEFAULT 0
);
Create table Course(
	CourseID INT Primary Key ,
	CourseName varchar (100) Not Null,
	Duration INT
);
create table Students (
	StudentID INT Primary Key , 
	StudentName Varchar(100)Not NULL,
	Email varchar(100) Not NUll,
	Phone Varchar(100)Not NULL,
	AcademicYearID INT NOT NULL,
	FOREIGN KEY (AcademicYearID)  REFERENCES AcademicYear(AcademicYearID) ON DELETE CASCADE 
);
Create Table Semester(
	SemesterID INT Primary Key,
	SemesterName varchar (100) Not Null,
	ActiveState BIT DEFAULT 0,
	AcademicYearID INT NOT NULL,
	FOREIGN KEY (AcademicYearID)  REFERENCES AcademicYear(AcademicYearID) ON DELETE CASCADE
);
Create Table Class(
	ClassID INT Primary Key,
	ClassName varchar(100) Not Null ,
	SemesterID  INT Not Null,
	InstructorID INT Not Null,
	CourseID INT Not Null,
	FOREIGN KEY (SemesterID)  REFERENCES Semester(SemesterID ) ON DELETE CASCADE,
	FOREIGN KEY (InstructorID)  REFERENCES Instructor(InstructorID ) ON DELETE CASCADE,
	FOREIGN KEY (CourseID)  REFERENCES Course(CourseID) ON DELETE CASCADE
);
create Table Exam(
	ExamID INT Primary Key,
	ExamType varchar (100) ,
	ExamDate Date ,
	ClassID INT NOT NULL,
	FOREIGN KEY (ClassID)  REFERENCES Class(ClassID) ON DELETE CASCADE
);

--Junction Tables 
Create Table Attendance(
	StudentID INT Not Null,
	ClassID Int Not Null,
	Date DATE Not Null,
	AttendanceStatus varchar(100) Not Null,
	LateMinutes INT DEFAULT 0,
	Primary Key (StudentID,ClassID,Date),
	FOREIGN KEY (StudentID) REFERENCES students(StudentID) ,
	FOREIGN KEY (ClassID)  REFERENCES Class(ClassID) ,
	CHECK (AttendanceStatus IN ('Present', 'Absent', 'Late'))
);
Create Table ExamMarkes(
	ExamID Int Not Null,
	StudentID Int Not Null,
	Grade float NOT NULL,
	FOREIGN KEY (ExamID) REFERENCES Exam(ExamID),
	FOREIGN KEY (StudentID) REFERENCES students(StudentID) 
);
Create Table Enrollment(
	StudentID Int Not Null,
	ClassID Int Not Null,
	EnrollmentDate Date Not Null,
	Primary key (StudentID,ClassID),
	FOREIGN KEY (StudentID) REFERENCES students(StudentID) ,
	FOREIGN KEY (ClassID)  REFERENCES Class(ClassID) 
);
Create Table CoursesAcademicYear(
	AcademicYearID INT NOT NULL,
	CourseID INT Not Null,
	Primary Key (AcademicYearID,CourseID),
	FOREIGN KEY (AcademicYearID)  REFERENCES AcademicYear(AcademicYearID) ,
	FOREIGN KEY (CourseID)  REFERENCES Course(CourseID) 
);

-------------------------------------------------------------------------------------
-- User-Defined Functions (UDFs)
-------------------------------------------------------------------------------------
-- Returns the currently active semester
CREATE FUNCTION GetActiveSemester()
RETURNS INT
AS
BEGIN
    DECLARE @SemesterID INT;
    SELECT @SemesterID = SemesterID FROM Semester WHERE ActiveState = 1;
    RETURN @SemesterID;
END;
-------------------------------------------------------------------------------------
-- Returns the number of courses an instructor teaches in the current semester
CREATE FUNCTION GetInstructorCourseCount(@InstructorID INT)
RETURNS INT
AS
BEGIN
    DECLARE @CourseCount INT;
    SELECT @CourseCount = COUNT(DISTINCT C.CourseID)
    FROM Course C
    JOIN Class CL ON C.CourseID = CL.CourseID
    WHERE CL.InstructorID = @InstructorID AND CL.SemesterID = dbo.GetActiveSemester();
    RETURN @CourseCount;
END;
-------------------------------------------------------------------------------------
-- Returns the number of classes an instructor teaches in the current semester
CREATE FUNCTION GetInstructorClassCount(@InstructorID INT)
RETURNS INT
AS
BEGIN
    DECLARE @ClassCount INT;
    SELECT @ClassCount = COUNT(CL.ClassID)
    FROM Class CL
    WHERE CL.InstructorID = @InstructorID AND CL.SemesterID = dbo.GetActiveSemester();
    RETURN @ClassCount;
END;

-------------------------------------------------------------------------------------
-- Stored Procedure to Add or Update an Instructor

CREATE PROCEDURE AddOrUpdateInstructor
    @ID INT,
	@Code varchar(20),
    @Name VARCHAR(100),
    @Email VARCHAR(100),
    @Phone VARCHAR(15)
AS
BEGIN
    IF EXISTS (SELECT 1 FROM Instructor WHERE InstructorID = @ID)
    BEGIN
        -- Update existing instructor
        UPDATE Instructor
        SET Code =@Code,InstructorName = @Name, Email = @Email, Mobile_Number = @Phone
        WHERE InstructorID = @ID;
    END
    ELSE
    BEGIN
        -- Insert new instructor
        INSERT INTO Instructor (InstructorID,Code,InstructorName, Email, Mobile_Number)
        VALUES (@ID, @Code,@Name, @Email, @Phone);
    END
END;
GO

-------------------------------------------------------------------------------------
-- Stored Procedure to Add or Update a Student
create procedure AddorUpdateStudent 
	@ID INT,
	@Name Varchar(100),
	@Email Varchar(100),
	@Phone Varchar(100),
	@AcademicYearID INT

AS
BEGIN 
	IF EXISTS (SELECT 1 FROM Students WHERE StudentID = @ID) 
    BEGIN
		-- Update existing Students
		Update Students
		SET  StudentName = @Name , Email = @Email,Phone = @Phone , AcademicYearID = @AcademicYearID
		Where StudentID = @ID ;
	END
	ELSE 
	BEGIN
		-- Insert New Students 
		INSERT INTO Students (StudentID,StudentName,Email,Phone,AcademicYearID)
		VALUES (@ID,@Name,@Email,@Phone,@AcademicYearID);
	END
END;
GO
-------------------------------------------------------------------------------------
--Batch Deletion of Instructors
Create procedure DeleteInstructors
	@InstructorIDs Varchar(max)
AS
BEGIN
	set NOCOUNT on ;

	Update Instructor
	set IsDeleted = 1
	where InstructorID in(select value from string_split(@InstructorIDs,','));

	PRINT 'Instructours Marked are Deleted Successfuly.!';
END;
-------------------------------------------------------------------------------------
--Search Stored Procedure for Instructors
CREATE PROCEDURE SearchInstructors
    @InstructorName VARCHAR(100) = NULL,
    @Email VARCHAR(100) = NULL,
    @Code VARCHAR(20) = NULL
AS
BEGIN
    SELECT I.InstructorName, I.Email, I.Code,
           dbo.GetInstructorCourseCount(I.InstructorID) AS CourseCount,
           dbo.GetInstructorClassCount(I.InstructorID) AS ClassCount
    FROM Instructor I
    WHERE I.IsDeleted = 0
    AND (@InstructorName IS NULL OR I.InstructorName LIKE '%' + @InstructorName + '%')
    AND (@Email IS NULL OR I.Email = @Email)
    AND (@Code IS NULL OR I.Code = @Code);
END;
-------------------------------------------------------------------------------------
--Attendance Management Stored Procedure
Create PROCEDURE RecordAttendance
	@StudentID INT ,
	@ClassID Int,
	@Date DATE ,
	@AttendanceStatus varchar(100), -- 'Present', 'Absent', 'Late'
	@LateMinutes INT = NULL -- Default NULL for non-late students

AS 
BEGIN
	SET NOCOUNT ON ;

	IF @AttendanceStatus NOT IN ('Present', 'Absent', 'Late')
	BEGIN
		PRINT 'Invalid attendance status. Must be Present, Absent, or Late.';
		RETURN ;
	END;
	IF @AttendanceStatus <> 'Late'
	BEGIN
		SET @LateMinutes = NULL;
	END;
	IF EXISTS (SELECT 1 FROM Attendance WHERE StudentID = @StudentID AND ClassID = @ClassID AND Date = @Date)
    BEGIN
        UPDATE Attendance
        SET AttendanceStatus = @AttendanceStatus, LateMinutes = @LateMinutes
        WHERE StudentID = @StudentID AND ClassID = @ClassID AND Date = @Date;
    END
    ELSE
	INSERT INTO Attendance (StudentID,ClassID ,Date ,AttendanceStatus ,LateMinutes)
	Values (@StudentID ,@ClassID ,@Date,@AttendanceStatus,@LateMinutes)
END;
-------------------------------------------------------------------------------------
--Attendance Retrieval Stored Procedure
CREATE PROCEDURE GetAttendanceRecords
    @AttendanceDate DATE,
    @ClassID INT,
    @CourseID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        s.StudentID,
        s.StudentName ,
        a.AttendanceStatus ,
        a.LateMinutes
    FROM Attendance a
    JOIN Students s ON a.StudentID = s.StudentID
    JOIN Class c ON a.ClassID = c.ClassID
    WHERE a.Date = @AttendanceDate
    AND a.ClassID = @ClassID
    AND c.CourseID = @CourseID;
END;
-------------------------------------------------------------------------------------
-- Instructor Courses View
CREATE VIEW InstructorCourses AS
SELECT I.InstructorID AS InstructorID,
I.InstructorName AS InstructorName, 
C.CourseID AS CourseID, 
C.CourseName AS CourseName, 
S.SemesterID AS SemesterID,
S.SemesterName AS SemesterName
FROM Instructor I
JOIN Class CL ON I.InstructorID = CL.InstructorID
JOIN Course C ON CL.CourseID = C.CourseID
JOIN Semester S ON CL.SemesterID = S.SemesterID;


-------------------------------------------------------------------------------------
-- Testing: Inserting Sample Data

-- Insert Academic Years
INSERT INTO AcademicYear (AcademicYearID, YearStart, YearEnd) VALUES (1, 2023, 2024);
INSERT INTO AcademicYear (AcademicYearID, YearStart, YearEnd) VALUES (2, 2024, 2025);

-- Insert Semesters
INSERT INTO Semester (SemesterID, SemesterName, ActiveState, AcademicYearID) VALUES (1, '«·Œ—Ì› 2023', 1, 1);
INSERT INTO Semester (SemesterID, SemesterName, ActiveState, AcademicYearID) VALUES (2, '«·—»Ì⁄ 2024', 0, 2);

-- Insert Instructors
INSERT INTO Instructor (InstructorID, Code, InstructorName, Email, Mobile_Number) 
VALUES (1, 'INST001', N'„Õ„œ ⁄·Ì', 'mohamed.ali@example.com', '1234567890');
INSERT INTO Instructor (InstructorID, Code, InstructorName, Email, Mobile_Number) 
VALUES (2, 'INST002', N'”«—… √Õ„œ', 'sara.ahmed@example.com', '0987654321');

-- Insert Courses
INSERT INTO Course (CourseID, CourseName, Duration) VALUES (1, N'«·—Ì«÷Ì« ', 6);
INSERT INTO Course (CourseID, CourseName, Duration) VALUES (2, N'«·›Ì“Ì«¡', 5);

-- Insert Classes
INSERT INTO Class (ClassID, ClassName, SemesterID, InstructorID, CourseID) 
VALUES (1, N'—Ì«÷Ì«  - «·’› «·√Ê·', 1, 1, 1);
INSERT INTO Class (ClassID, ClassName, SemesterID, InstructorID, CourseID) 
VALUES (2, N'›Ì“Ì«¡ - «·’› «·À«‰Ì', 1, 2, 2);

-- Insert Students
INSERT INTO Students (StudentID, StudentName, Email, Phone, AcademicYearID) 
VALUES (1, N'Œ«·œ ⁄»œ «··Â', 'khaled.abdullah@example.com', '9876543210', 1);
INSERT INTO Students (StudentID, StudentName, Email, Phone, AcademicYearID) 
VALUES (2, N'√„Ì‰… Õ”‰', 'amina.hassan@example.com', '9876543220', 1);

-- Insert Enrollments
INSERT INTO Enrollment (StudentID, ClassID, EnrollmentDate) VALUES (1, 1, '2025-02-19');
INSERT INTO Enrollment (StudentID, ClassID, EnrollmentDate) VALUES (2, 2, '2025-02-19');

-- Insert Attendance
INSERT INTO Attendance (StudentID, ClassID, Date, AttendanceStatus, LateMinutes) 
VALUES (1, 1, '2025-02-19', 'Present', 0);
INSERT INTO Attendance (StudentID, ClassID, Date, AttendanceStatus, LateMinutes) 
VALUES (2, 2, '2025-02-19', 'Late', 10);

-- Insert Exams
INSERT INTO Exam (ExamID, ExamType, ExamDate, ClassID) VALUES (1, 'Midterm', '2025-03-01', 1);
INSERT INTO Exam (ExamID, ExamType, ExamDate, ClassID) VALUES (2, 'Final', '2025-06-10', 2);

-- Insert Exam Marks
INSERT INTO ExamMarkes (ExamID, StudentID, Grade) VALUES (1, 1, 95.0);
INSERT INTO ExamMarkes (ExamID, StudentID, Grade) VALUES (2, 2, 88.5);

-- Insert Course-Academic Year Relationships
INSERT INTO CoursesAcademicYear (AcademicYearID, CourseID) VALUES (1, 1);
INSERT INTO CoursesAcademicYear (AcademicYearID, CourseID) VALUES (2, 2);

-- Stored Procedure Test: Add or Update Instructor
EXEC AddOrUpdateInstructor 3, 'INST003', N'√Õ„œ ”„Ì—', 'ahmed.samir@example.com', '01122334455';
EXEC AddOrUpdateInstructor 1, 'INST001A', N'„Õ„œ ⁄·Ì «·„ÕœÀ', 'mohamed.ali.updated@example.com', '1234567899';

-- Stored Procedure Test: Add or Update Student
EXEC AddOrUpdateStudent 3, N'ÌÊ”› Õ”‰', 'yousef.hassan@example.com', '0123456789', 1;
EXEC AddOrUpdateStudent 1, N'Œ«·œ ⁄»œ «··Â «·„ÕœÀ', 'khaled.abdullah.updated@example.com', '9876543211', 2;

-- Stored Procedure Test: Delete Instructors
EXEC DeleteInstructors '1,2';

-- Stored Procedure Test: Search Instructors
EXEC SearchInstructors N'„Õ„œ', NULL, NULL;
EXEC SearchInstructors NULL, 'mohamed.ali@example.com', NULL;

-- Stored Procedure Test: Record Attendance
EXEC RecordAttendance 1, 1, '2025-02-19', 'Present', NULL;
EXEC RecordAttendance 2, 2, '2025-02-19', 'Late', 5;

-- Stored Procedure Test: Get Attendance Records
EXEC GetAttendanceRecords '2025-02-19', 1, 1;
EXEC GetAttendanceRecords '2025-02-19', 2, 2;


-- Verify Data
SELECT * FROM AcademicYear;
SELECT * FROM Semester;
SELECT * FROM Instructor;
SELECT * FROM Course;
SELECT * FROM Class;
SELECT * FROM Students;
SELECT * FROM Enrollment;
SELECT * FROM Attendance;
SELECT * FROM Exam;
SELECT * FROM ExamMarkes;
SELECT * FROM CoursesAcademicYear;
-------------------------------------------------------------------------------------















