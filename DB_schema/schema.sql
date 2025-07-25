DROP TABLE IF EXISTS Ratings;
DROP TABLE IF EXISTS Users;
DROP TABLE IF EXISTS Books;

CREATE TABLE Books (
    ISBN VARCHAR(45) PRIMARY KEY,
    Book_title VARCHAR(250),
    Book_Author VARCHAR(250),
    Year_of_publication VARCHAR(45),
    Publisher VARCHAR(250),
    image_url_s VARCHAR(250),
    image_url_m VARCHAR(250),
    image_url_l VARCHAR(250)
);

CREATE TABLE Users (
    user_id INT PRIMARY KEY,
    Location VARCHAR(250),
    Age VARCHAR(45)
);

CREATE TABLE Ratings (
    user_id INT,
    ISBN VARCHAR(45),
    Book_rating VARCHAR(45),
    PRIMARY KEY (user_id, ISBN), 
    FOREIGN KEY (user_id) REFERENCES Users(user_id),
    FOREIGN KEY (ISBN) REFERENCES Books(ISBN)
);

