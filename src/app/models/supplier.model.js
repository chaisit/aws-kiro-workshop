const mysql = require("mysql2");
const dbConfig = require("../config/config");
// constructor
const Supplier = function (supplier) {
    this.id = supplier.id;
    this.name = supplier.name;
    this.address = supplier.address;
    this.city = supplier.city;
    this.state = supplier.state;
    this.email = supplier.email;
    this.phone = supplier.phone;
};
// connecting on each request so the server will start without a db connection, plus
//   a simple mechanism enabling the app to recover from a momentary missing db connection
Supplier.dbConnect = () => {
    const connection = mysql.createConnection({
        host: dbConfig.APP_DB_HOST,
        user: dbConfig.APP_DB_USER,
        password: dbConfig.APP_DB_PASSWORD,
        database: dbConfig.APP_DB_NAME
    });
    connection.connect(error => {
        if (error) {
            console.log("Error connecting to Db")
            throw error;
        }
        console.log("Successfully connected to the database.");
    });
    return connection;
}

Supplier.create = (newSupplier, result) => {
    const dbConn = Supplier.dbConnect();
    dbConn.query("INSERT INTO students SET ?", newSupplier, (err, res) => {
        if (err) {
            console.log("error: ", err);
            result(err, null);
            return;
        }
        console.log("created supplier: ", {id: res.insertId, ...newSupplier});
        result(null, {id: res.insertId, ...newSupplier});
    });
};

Supplier.getAll = result => {
    const dbConn = Supplier.dbConnect();
    dbConn.query("SELECT * FROM students", (err, res) => {
        if (err) {
            console.log("error: ", err);
            result(err, null);
            return;
        }
        console.log("Students: ", res);
        result(null, res);
    });
};

Supplier.findById = (supplierId, result) => {
    const dbConn = Supplier.dbConnect();
    dbConn.query(`SELECT * FROM students WHERE id = ${supplierId}`, (err, res) => {
        if (err) {
            console.log("error: ", err);
            result(err, null);
            return;
        }
        if (res.length) {
            console.log("found supplier: ", res[0]);
            result(null, res[0]);
            return;
        }
        result({kind: "not_found"}, null);
    });
};

Supplier.updateById = (id, supplier, result) => {
    const dbConn = Supplier.dbConnect();
    dbConn.query(
        "UPDATE students SET name = ?, city = ?, address = ?, email = ?, phone = ?, state = ? WHERE id = ?",
        [supplier.name, supplier.city, supplier.address, supplier.email, supplier.phone, supplier.state, id],
        (err, res) => {
            if (err) {
                console.log("error: ", err);
                result(err, null);
                return;
            }
            if (res.affectedRows === 0) {
                result({kind: "not_found"}, null);
                return;
            }
            console.log("updated supplier: ", {id: id, ...supplier});
            result(null, {id: id, ...supplier});
        }
    );
};

Supplier.delete = (id, result) => {
    const dbConn = Supplier.dbConnect();
    dbConn.query("DELETE FROM students WHERE id = ?", id, (err, res) => {
        if (err) {
            console.log("error: ", err);
            result(err, null);
            return;
        }
        if (res.affectedRows === 0) {
            result({kind: "not_found"}, null);
            return;
        }
        console.log("deleted student with id: ", id);
        result(null, res);
    });
};

Supplier.removeAll = result => {
    const dbConn = Supplier.dbConnect();
    dbConn.query("DELETE FROM students", (err, res) => {
        if (err) {
            console.log("error: ", err);
            result(err, null);
            return;
        }
        console.log(`deleted ${res.affectedRows} students`);
        result(null, res);
    });
};

module.exports = Supplier;