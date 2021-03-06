/*
 * Copyright 2015 Telefónica I+D
 * All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may
 * not use this file except in compliance with the License. You may obtain
 * a copy of the License at
 *
 *         http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */
'use strict';

var express = require('express'),
    router = express.Router(),
    dateFormat = require('dateformat'),
    cbroker = require('./cbroker'),
    domain = require('domain'),
    logger = require('../logger');

/* GET home page. */
router.get('/', function (req, res) {


    req.session.title_timestamp = dateFormat(new Date(), 'yyyy-mm-dd H:MM:ss');
    cbroker.retrieveAllRegions(function (regions) {

        logger.info({op: 'index#get'}, 'regions:' + regions);

        res.render('index', {timestamp: req.session.title_timestamp, regions: regions});

    });

});

/** @export */
module.exports = router;
