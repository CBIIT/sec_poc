var createError = require('http-errors');
var express = require('express');
const session = require('express-session');
var path = require('path');
var cookieParser = require('cookie-parser');
var logger = require('morgan');


var indexRouter = require('./routes/index');
var launchRouter = require('./routes/launch');
var cernerRouter = require('./routes/cerner');
var appRouter = require('./routes/app');

var app = express();

// view engine setup
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'pug');



app.use(logger('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));
app.use('/css', express.static(path.join(__dirname + '/node_modules/bootstrap/dist/css')));
app.use('/js', express.static(path.join(__dirname + '/node_modules/bootstrap/dist/js')));

app.use(session({
  secret: "my secret",
  resave: false,
  saveUninitialized: false
}));

// Home route
app.use('/', indexRouter);
// Cerner routes
app.use('/cerner', cernerRouter);
// EPIC routes
app.use('/app', appRouter);
app.use('/launch', launchRouter);

// catch 404 and forward to error handler
app.use(function(req, res, next) {
  next(createError(404));
});

// error handler
app.use(function(err, req, res, next) {
  // set locals, only providing error in development
  res.locals.message = err.message;
  res.locals.error = req.app.get('env') === 'development' ? err : {};

  // render the error page
  res.status(err.status || 500);
  res.render('error');
});

module.exports = app;
