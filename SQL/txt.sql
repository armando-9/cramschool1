/*
  Cleaned and reordered SQL script for cramschool project (Fixed to Match ER Diagram)
  - Fixed column names/mismatches: e.g., phone_number (not Phone_number), zip_number, road_number, district_id/province_id (INT FKs, not strings district_d/a/Province).
  - Student: student_name single field (combined name + lastname); no lastname separate.
  - Register: studygroup_id (not group_id).
  - StudyGroup: studygroup_id (not group_id); ist_id FK to Instructor.
  - Course: Only diagram fields (course_nameTH/ENG, tuitionfees DECIMAL, course_list, hours_study); removed non-matching (short/long desc, price, category_id, instructor_id).
  - DelCourse: Manual cascade (Register -> StudyGroup -> Course).
  - Instructor: ist_lastname (lowercase 'l'), picture NULL ok.
  - Seed data: Adjusted inserts to match columns; used sample INT IDs for district/province; tuitionfees as DECIMAL.
  - Standardized: VARCHAR lengths, DROP/GO for safe re-run, error handling in SPs where needed.
  - Ensured procedures created before seed; transaction for seed integrity.
*/

-- =====================
-- Student procedures
-- =====================
IF OBJECT_ID('dbo.AddStudent','P') IS NOT NULL
    DROP PROCEDURE dbo.AddStudent;
GO

CREATE PROCEDURE dbo.AddStudent
    @picture_number VARCHAR(100) = NULL,  -- Optional
    @zip_number     VARCHAR(20),
    @phone_number   VARCHAR(20),
    @road_number    VARCHAR(100),
    @district_id    INT,
    @province_id    INT,
    @student_name   VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Student (picture_number, zip_number, phone_number, road_number, district_id, province_id, student_name)
    VALUES (@picture_number, @zip_number, @phone_number, @road_number, @district_id, @province_id, @student_name);
END;
GO

IF OBJECT_ID('dbo.DelStudent','P') IS NOT NULL
    DROP PROCEDURE dbo.DelStudent;
GO

CREATE PROCEDURE dbo.DelStudent
    @student_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM Student WHERE student_id = @student_id;
END;
GO

IF OBJECT_ID('dbo.EditStudent','P') IS NOT NULL
    DROP PROCEDURE dbo.EditStudent;
GO

CREATE PROCEDURE dbo.EditStudent
    @student_id      INT,
    @picture_number  VARCHAR(100) = NULL,
    @zip_number      VARCHAR(20),
    @phone_number    VARCHAR(20),
    @road_number     VARCHAR(100),
    @district_id     INT,
    @province_id     INT,
    @student_name    VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Student
    SET
        picture_number = ISNULL(@picture_number, picture_number),
        zip_number = @zip_number,
        phone_number = @phone_number,
        road_number = @road_number,
        district_id = @district_id,
        province_id = @province_id,
        student_name = @student_name
    WHERE student_id = @student_id;
END;
GO

-- =====================
-- Register procedures
-- =====================
-- 1. (สร้างใหม่) SP สำหรับโหลดข้อมูลลงตาราง (DataGridView)
-- (ใช้ SP นี้แทนการเขียน SQL ยาวๆ ใน C#)
IF OBJECT_ID('sp_GetRegistrationDetails', 'P') IS NOT NULL
    DROP PROCEDURE sp_GetRegistrationDetails
GO

CREATE PROCEDURE sp_GetRegistrationDetails
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        r.register_id, 
        r.status, 
        r.dateregister, 
        r.student_id, -- ซ่อนไว้ แต่จำเป็น
        (s.student_name + ' ' + s.student_lastname) AS StudentName,
        r.group_id,   -- ซ่อนไว้ แต่จำเป็น
        (c.course_list + ': ' + c.course_nameTH + ' (Room: ' + sg.room + ')') AS GroupName
    FROM 
        register r
    LEFT JOIN 
        student s ON r.student_id = s.student_id
    LEFT JOIN 
        studygroup sg ON r.group_id = sg.group_id
    LEFT JOIN 
        course c ON sg.course_id = c.course_id
    ORDER BY
        r.dateregister DESC;
END
GO

-- 2. (สร้างทับ) SP สำหรับ "เพิ่ม" (Add)
-- (แก้ไขให้รับ ID นักเรียนและกลุ่ม)
ALTER PROCEDURE AddRegister
    @status NVARCHAR(50),
    @dateregister DATE,
    @student_id INT,
    @group_id INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- ป้องกันการลงทะเบียนซ้ำ (นักเรียนคนนี้ลงกลุ่มนี้ไปแล้ว)
    IF EXISTS (SELECT 1 FROM register WHERE student_id = @student_id AND group_id = @group_id)
    BEGIN
        RAISERROR ('นักเรียนคนนี้ได้ลงทะเบียนในกลุ่มนี้ไปแล้ว', 16, 1);
        RETURN;
    END

    INSERT INTO register (status, dateregister, student_id, group_id)
    VALUES (@status, @dateregister, @student_id, @group_id);
END
GO

-- 3. (สร้างทับ) SP สำหรับ "แก้ไข" (Edit)
-- (แก้ไขเฉพาะ Status และ Date)
ALTER PROCEDURE EditRegister
    @register_id INT,
    @status NVARCHAR(50),
    @dateregister DATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE register
    SET 
        status = @status,
        dateregister = @dateregister
    WHERE 
        register_id = @register_id;
END
GO

-- 4. (สร้างทับ) SP สำหรับ "ลบ" (Delete)
ALTER PROCEDURE DelRegister
    @register_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM register
    WHERE register_id = @register_id;
END
GO
PRINT '--- Stored Procedures ทั้ง 4 ตัว อัปเดตสำเร็จ ---';
-- =====================
-- Course procedures
-- =====================
IF OBJECT_ID('dbo.AddCourse','P') IS NOT NULL
    DROP PROCEDURE dbo.AddCourse;
GO

CREATE PROCEDURE dbo.AddCourse
    @course_nameTH  VARCHAR(200),
    @course_nameENG VARCHAR(200),
    @tuitionfees    DECIMAL(10,2),
    @course_list    VARCHAR(200),
    @hours_study    INT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Course (course_nameTH, course_nameENG, tuitionfees, course_list, hours_study)
    VALUES (@course_nameTH, @course_nameENG, @tuitionfees, @course_list, @hours_study);
END;
GO

IF OBJECT_ID('dbo.DelCourse','P') IS NOT NULL
    DROP PROCEDURE dbo.DelCourse;
GO

CREATE PROCEDURE dbo.DelCourse
    @course_id INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            -- Cascade delete: Register -> StudyGroup -> Course
            DELETE FROM Register WHERE studygroup_id IN (SELECT studygroup_id FROM StudyGroup WHERE course_id = @course_id);
            DELETE FROM StudyGroup WHERE course_id = @course_id;
            DELETE FROM Course WHERE course_id = @course_id;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

IF OBJECT_ID('dbo.EditCourse','P') IS NOT NULL
    DROP PROCEDURE dbo.EditCourse;
GO

CREATE PROCEDURE dbo.EditCourse
    @course_id      INT,
    @course_nameTH  VARCHAR(200),
    @course_nameENG VARCHAR(200),
    @tuitionfees    DECIMAL(10,2),
    @course_list    VARCHAR(200),
    @hours_study    INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Course
    SET
        course_nameTH = @course_nameTH,
        course_nameENG = @course_nameENG,
        tuitionfees = @tuitionfees,
        course_list = @course_list,
        hours_study = @hours_study
    WHERE course_id = @course_id;
END;
GO

-- =====================
-- StudyGroup procedures
-- =====================
IF OBJECT_ID('dbo.AddStudyGroup','P') IS NOT NULL
    DROP PROCEDURE dbo.AddStudyGroup;
GO

CREATE PROCEDURE dbo.AddStudyGroup
    @startdate     DATE,
    @enddate       DATE,
    @status        VARCHAR(50),
    @room          VARCHAR(50),
    @course_id     INT,
    @ist_id        INT  -- FK to Instructor
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO StudyGroup (startdate, enddate, status, room, course_id, ist_id)
    VALUES (@startdate, @enddate, @status, @room, @course_id, @ist_id);
END;
GO

IF OBJECT_ID('dbo.DelStudyGroup','P') IS NOT NULL
    DROP PROCEDURE dbo.DelStudyGroup;
GO

CREATE PROCEDURE dbo.DelStudyGroup
    @studygroup_id INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            -- Cascade: Delete related Register first
            DELETE FROM Register WHERE studygroup_id = @studygroup_id;
            DELETE FROM StudyGroup WHERE studygroup_id = @studygroup_id;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

IF OBJECT_ID('dbo.EditStudyGroup','P') IS NOT NULL
    DROP PROCEDURE dbo.EditStudyGroup;
GO

CREATE PROCEDURE dbo.EditStudyGroup
    @studygroup_id  INT,
    @startdate      DATE,
    @enddate        DATE,
    @status         VARCHAR(50),
    @room           VARCHAR(50),
    @course_id      INT,
    @ist_id         INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE StudyGroup
    SET
        startdate = @startdate,
        enddate = @enddate,
        status = @status,
        room = @room,
        course_id = @course_id,
        ist_id = @ist_id
    WHERE studygroup_id = @studygroup_id;
END;
GO

-- =====================
-- Instructor procedures
-- =====================
IF OBJECT_ID('dbo.AddInstructor','P') IS NOT NULL
    DROP PROCEDURE dbo.AddInstructor;
GO

CREATE PROCEDURE dbo.AddInstructor
    @ist_name     VARCHAR(100),
    @ist_lastname VARCHAR(100),
    @namenumber   VARCHAR(20),
    @mobilenumber VARCHAR(20),
    @email        VARCHAR(255),
    @picture      VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Instructor (ist_name, ist_lastname, namenumber, mobilenumber, email, picture)
    VALUES (@ist_name, @ist_lastname, @namenumber, @mobilenumber, @email, @picture);
END;
GO

IF OBJECT_ID('dbo.DelInstructor','P') IS NOT NULL
    DROP PROCEDURE dbo.DelInstructor;
GO

CREATE PROCEDURE dbo.DelInstructor
    @ist_id INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            -- Cascade: Delete related StudyGroup first (if any)
            DELETE FROM StudyGroup WHERE ist_id = @ist_id;
            DELETE FROM Instructor WHERE ist_id = @ist_id;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

IF OBJECT_ID('dbo.EditInstructor','P') IS NOT NULL
    DROP PROCEDURE dbo.EditInstructor;
GO

CREATE PROCEDURE dbo.EditInstructor
    @ist_id        INT,
    @ist_name      VARCHAR(100),
    @ist_lastname  VARCHAR(100),
    @namenumber    VARCHAR(20),
    @mobilenumber  VARCHAR(20),
    @email         VARCHAR(255),
    @picture       VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Instructor
    SET
        ist_name = @ist_name,
        ist_lastname = @ist_lastname,
        namenumber = @namenumber,
        mobilenumber = @mobilenumber,
        email = @email,
        picture = ISNULL(@picture, picture)
    WHERE ist_id = @ist_id;
END;
GO

-- =====================
-- Sample seed data (2 rows per table, fixed for FK consistency)
-- =====================
-- Assume District/Province tables exist with IDs (e.g., Bangkok district=1, province=1; Khon Kaen=2).
-- Student name combined (no separate lastname).

BEGIN TRANSACTION;
    DECLARE @stu1 INT, @stu2 INT;
    DECLARE @ist1 INT, @ist2 INT;
    DECLARE @course1 INT, @course2 INT;
    DECLARE @group1 INT, @group2 INT;  -- studygroup_id

    -- Students
    INSERT INTO Student (zip_number, phone_number, road_number, district_id, province_id, student_name)
    VALUES ('46170', '0912345678', '1 Sukhumvit', 1, 1, 'Anan Srisuk');  -- Combined name
    SET @stu1 = SCOPE_IDENTITY();

    INSERT INTO Student (zip_number, phone_number, road_number, district_id, province_id, student_name)
    VALUES ('40000', '0897654321', '22 Mittraphap', 1, 2, 'Kanya Phonchai');
    SET @stu2 = SCOPE_IDENTITY();

    -- Instructors
    INSERT INTO Instructor (ist_name, ist_lastname, namenumber, mobilenumber, email)
    VALUES ('Sudarat', 'Thongchai', 'ST001', '0891112233', 'sudarat.th@university.ac.th');
    SET @ist1 = SCOPE_IDENTITY();

    INSERT INTO Instructor (ist_name, ist_lastname, namenumber, mobilenumber, email)
    VALUES ('Prasert', 'Manee', 'PM002', '0892223344', 'prasert.ma@university.ac.th');
    SET @ist2 = SCOPE_IDENTITY();

    -- Courses
    INSERT INTO Course (course_nameTH, course_nameENG, tuitionfees, course_list, hours_study)
    VALUES (N'พื้นฐานการเขียนโปรแกรม', 'Programming Fundamentals', 3500.00, 'PF101', 45);
    SET @course1 = SCOPE_IDENTITY();

    INSERT INTO Course (course_nameTH, course_nameENG, tuitionfees, course_list, hours_study)
    VALUES (N'ระบบฐานข้อมูล', 'Database Systems', 4000.00, 'DB201', 60);
    SET @course2 = SCOPE_IDENTITY();

    INSERT INTO Course (course_nameTH, course_nameENG, tuitionfees, course_list, hours_study)
    VALUES (N'โครงสร้างข้อมูล', 'Data Structures', 4500.00, 'DS301', 75);
    

    

    -- StudyGroups (reference courses and instructors)
    INSERT INTO StudyGroup (startdate, enddate, status, room, course_id, ist_id)
    VALUES ('2025-07-01', '2025-10-01', 'Active', '101', @course1, @ist1);
    SET @group1 = SCOPE_IDENTITY();

    INSERT INTO StudyGroup (startdate, enddate, status, room, course_id, ist_id)
    VALUES ('2025-07-15', '2025-10-15', 'Active', '202', @course2, @ist2);
    SET @group2 = SCOPE_IDENTITY();

    -- Registers (reference students and studygroups)
    INSERT INTO Register (status, dateregister, student_id, studygroup_id)
    VALUES ('Active', GETDATE(), @stu1, @group1);

    INSERT INTO Register (status, dateregister, student_id, studygroup_id)
    VALUES ('Pending', DATEADD(day, 1, GETDATE()), @stu2, @group2);

COMMIT TRANSACTION;
-- =====================
    -- Stroed Procddure
-- =====================
CREATE PROCEDURE sp_SearchRegistrantsByCourseName
    @CourseName NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        s.student_id AS StudentID,
        s.student_name AS RegistrantName,  -- สมมติมี student_name ใน Student
        s.phone_number AS PhoneNumber,
        c.course_nameTH AS CourseNameTH,
        c.course_nameENG AS CourseNameENG,
        c.course_list AS CourseCode,
        c.hours_study AS StudyHours,
        sg.startdate AS StartDate,  -- ใช้ startdate จาก StudyGroup แทน registration_date
        r.status AS RegistrationStatus
    FROM Register r
    INNER JOIN Student s ON r.student_id = s.student_id
    INNER JOIN StudyGroup sg ON r.group_id = sg.group_id
    INNER JOIN Course c ON sg.course_id = c.course_id
    WHERE 
        (c.course_nameTH LIKE '%' + @CourseName + '%') 
        OR (c.course_nameENG LIKE '%' + @CourseName + '%')
        AND r.status = 'Active'  -- กรองเฉพาะที่ active (ปรับได้ถ้าต้องการ)
    ORDER BY s.student_name;

END;
EXEC sp_SearchRegistrantsByCourseName @CourseName = N'พื้นฐานการเขียนโปรแกรม'
SELECT course_id, course_nameTH FROM Course ORDER BY course_nameTH;

-- Stored Procedure: sp_SearchStudyGroupsByCourseName
-- Description: ค้นหาหมู่เรียน (study groups) โดยกรองจากชื่อหลักสูตร (course_nameTH)
--              ถ้าไม่ระบุชื่อหลักสูตร (NULL) จะแสดงหมู่เรียนทั้งหมด

-- ใช้ ALTER PROCEDURE เพื่อแก้ไข/ทับ SP ตัวเดิม
ALTER PROCEDURE sp_SearchStudyGroupsByCourseName
    @CourseName NVARCHAR(255) = NULL -- รับค่าชื่อหลักสูตร (TH)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        sg.group_id,
        c.course_nameTH,
        c.course_list,
        (i.ist_name + ' ' + i.ist_lastname) AS InstructorName, -- รวมชื่อ-สกุลผู้สอน
        sg.startdate,
        sg.enddate,
        sg.room,
        sg.status
    FROM 
        studygroup sg
    INNER JOIN 
        course c ON sg.course_id = c.course_id -- Join เพื่อเอาชื่อหลักสูตร
    INNER JOIN 
        instructor i ON sg.ist_id = i.ist_id -- Join เพื่อเอาชื่อผู้สอน
    WHERE 
        -- ถ้า @CourseName เป็น NULL ให้แสดงทั้งหมด (ค้นหาทั้งหมด)
        -- ถ้ามีค่า ให้กรองตาม course_nameTH ที่ตรงกัน
        (@CourseName IS NULL OR c.course_nameTH = @CourseName)
    ORDER BY 
        sg.startdate DESC; -- เรียงตามวันที่เริ่มเรียนล่าสุด
END
GO
EXEC sp_SearchStudyGroupsByCourseName;
EXEC sp_SearchStudyGroupsByCourseName @CourseName = N'ระบบฐานข้อมูล';
-- Stored Procedure: sp_SearchStudentsByID
-- Description: ค้นหานักเรียน ถ้า @StudentID = NULL จะแสดงทั้งหมด
--              ถ้า @StudentID_is_set, จะกรองเฉพาะคนนั้น
CREATE PROCEDURE sp_SearchStudentsByID
    @StudentID INT = NULL -- พารามิเตอร์นี้รับ ID นักเรียน (optional)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        student_id,
        student_name,
        student_lastname,
        Phone_number,
        road,
        district_a,
        Province,
        zipcode
    FROM 
        student
    WHERE
        -- ถ้า @StudentID เป็น NULL (ไม่ได้ระบุ) ให้แสดงทั้งหมด
        -- ถ้า @StudentID มีค่า ให้กรองเฉพาะ ID นั้น
        (@StudentID IS NULL OR student_id = @StudentID)
    ORDER BY
        student_name, student_lastname;
END
GO
EXEC sp_SearchStudentsByID; -- แสดงทั้งหมด
EXEC sp_SearchStudentsByID @StudentID = 1; -- แสดงเฉพาะนักเรียน ID = 1
-- Stored Procedure: sp_SearchCoursesByName
-- Description: ค้นหารายละเอียดหลักสูตร ถ้า @CourseName = NULL จะแสดงทั้งหมด
CREATE PROCEDURE sp_SearchCoursesByName
    @CourseName NVARCHAR(255) = NULL -- รับค่าชื่อหลักสูตร (TH) (optional)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        course_id,
        course_list,        -- รหัสวิชา
        course_nameTH,      -- ชื่อไทย
        course_nameENG,     -- ชื่ออังกฤษ
        tuitionfees,        -- ค่าเล่าเรียน
        hours_study         -- ชั่วโมงเรียน
    FROM 
        course
    WHERE
        -- ถ้า @CourseName เป็น NULL (ไม่ได้ระบุ) ให้แสดงทั้งหมด
        -- ถ้า @CourseName มีค่า ให้กรองเฉพาะชื่อ (TH) นั้น
        (@CourseName IS NULL OR course_nameTH = @CourseName)
    ORDER BY
        course_nameTH;
END
GO
EXEC sp_SearchCoursesByName; -- แสดงทั้งหมด
EXEC sp_SearchCoursesByName @CourseName = N'ระบบฐานข้อมูล'; -- แสดงเฉพาะหลักสูตร 'ระบบฐานข้อมูล'
-- Stored Procedure: sp_SearchCompletedStudentsByCourse
-- Description: ค้นหานักเรียนที่เรียนจบ (status = 'Completed') 
--              และกรองตามชื่อหลักสูตร (ถ้ามี)

CREATE PROCEDURE sp_SearchCompletedStudentsByCourse
    @CourseName NVARCHAR(255) = NULL -- รับค่าชื่อหลักสูตร (TH) (optional)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        s.student_id,
        s.student_name,
        s.student_lastname,
        c.course_nameTH,      -- แสดงว่าจบจากคอร์สไหน
        r.dateregister,       -- วันที่ลงทะเบียน
        r.status              -- สถานะ (เช่น Completed)
    FROM 
        student s
    INNER JOIN 
        register r ON s.student_id = r.student_id
    INNER JOIN 
        studygroup sg ON r.group_id = sg.group_id  -- (อิงตาม ERD ของคุณ)
    INNER JOIN 
        course c ON sg.course_id = c.course_id
    WHERE
        -- 1. กรองเฉพาะสถานะ "เรียนจบ"
        -- *** (สำคัญ) แก้ 'Completed' ให้เป็นสถานะที่ถูกต้องของคุณ ***
        -- *** เช่น 'เรียนจบ', 'Pass', 'Success' ฯลฯ ***
        r.status = 'Completed' 
        
        -- 2. กรองตามชื่อหลักสูตร (ถ้า @CourseName ไม่ใช่ NULL)
        AND (@CourseName IS NULL OR c.course_nameTH = @CourseName)
    ORDER BY
        c.course_nameTH, s.student_name;
END
GO
EXEC sp_SearchCompletedStudentsByCourse; -- แสดงทั้งหมด
EXEC sp_SearchCompletedStudentsByCourse @CourseName = N'พื้นฐานการเขียนโปรแกรม'; -- แสดงเฉพาะหลักสูตร 'พื้นฐานการเขียนโปรแกรม'
-- =====================
-- Helpful SELECTs (commented) - use in SSMS to inspect data
-- =====================
/*
SELECT * FROM Student;
SELECT * FROM Register;
SELECT * FROM Course;
SELECT * FROM StudyGroup;
SELECT * FROM Instructor;
*/
PRINT '--- 1. กำลังแก้ไข sp_GetRegistrationDetails (เอา TRY_CAST ออก) ---';
ALTER PROCEDURE sp_GetRegistrationDetails
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        r.register_id, 
        r.status, 
        r.dateregister, 
        r.student_id, -- ตอนนี้เป็น INT แล้ว
        s.student_name AS StudentName,     
        r.group_id,   -- ตอนนี้เป็น INT แล้ว
        (c.course_list + ': ' + c.course_nameTH + ' (Room: ' + sg.room + ')') AS GroupName
    FROM 
        register r
    LEFT JOIN 
        student s ON r.student_id = s.student_id -- JOIN ตรงๆ ได้เลย
    LEFT JOIN 
        studygroup sg ON r.group_id = sg.group_id -- JOIN ตรงๆ ได้เลย
    LEFT JOIN 
        course c ON sg.course_id = c.course_id
    ORDER BY
        r.dateregister DESC;
END
GO 

PRINT '--- 2. กำลังแก้ไข sp_SearchRegistrantsByCourseName (เอา TRY_CAST ออก) ---';
ALTER PROCEDURE sp_SearchRegistrantsByCourseName
    @CourseName NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        s.student_id AS StudentID,
        s.student_name AS RegistrantName,
        s.phone_number AS PhoneNumber,
        c.course_nameTH AS CourseNameTH,
        c.course_nameENG AS CourseNameENG,
        c.course_list AS CourseCode,
        c.hours_study AS StudyHours,
        sg.startdate AS StartDate,
        r.status AS RegistrationStatus
    FROM Register r
    INNER JOIN Student s ON r.student_id = s.student_id -- JOIN ตรงๆ
    INNER JOIN StudyGroup sg ON r.group_id = sg.group_id -- JOIN ตรงๆ
    INNER JOIN Course c ON sg.course_id = c.course_id
    WHERE 
        ( 
            (@CourseName IS NULL) OR
            (c.course_nameTH LIKE '%' + @CourseName + '%') OR 
            (c.course_nameENG LIKE '%' + @CourseName + '%')
        )
        AND r.status = 'Active' 
    ORDER BY s.student_name;
END
GO 

-- (sp_SearchStudentsByID ไม่มีการ CAST อยู่แล้ว ไม่ต้องแก้)

PRINT '--- 4. กำลังแก้ไข sp_SearchCompletedStudentsByCourse (เอา TRY_CAST ออก) ---';
ALTER PROCEDURE sp_SearchCompletedStudentsByCourse
    @CourseName NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        s.student_id,
        s.student_name, 
        c.course_nameTH,
        r.dateregister,
        r.status
    FROM 
        student s
    INNER JOIN 
        register r ON r.student_id = s.student_id -- JOIN ตรงๆ
    INNER JOIN 
        studygroup sg ON r.group_id = sg.group_id -- JOIN ตรงๆ
    INNER JOIN 
        course c ON sg.course_id = c.course_id
    WHERE
        r.status = 'Completed'
        AND (@CourseName IS NULL OR c.course_nameTH = @CourseName)
    ORDER BY
        c.course_nameTH, s.student_name;
END
GO 

PRINT '--- อัปเดต Stored Procedure (ฉบับไม่มี CAST) เสร็จสมบูรณ์ ---';
-- (คำเตือน: คำสั่งนี้จะลบข้อมูล)
-- ดูข้อมูลที่มีปัญหาก่อนลบ
SELECT * FROM register WHERE ISNUMERIC(student_id) = 0 OR ISNUMERIC(group_id) = 0;
-- ลบข้อมูลที่มีปัญหา
-- DELETE FROM register WHERE ISNUMERIC(student_id) = 0 OR ISNUMERIC(group_id) = 0;
-- (รันใน SSMS หลังจากลบข้อมูลผิดๆ ออกแล้ว)
ALTER TABLE register ALTER COLUMN student_id INT;
ALTER TABLE register ALTER COLUMN group_id INT;