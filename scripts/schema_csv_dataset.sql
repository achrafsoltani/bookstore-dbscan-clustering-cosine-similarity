DROP TABLE IF EXISTS Ratings;
DROP TABLE IF EXISTS Users;

CREATE TABLE Users (
    user_id INT PRIMARY KEY,
    Location VARCHAR(250),
    Age INT
);

CREATE TABLE Ratings (
    user_id INT,
    ISBN VARCHAR(45),
    Book_rating SMALLINT,
    PRIMARY KEY (user_id, ISBN),
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
);

