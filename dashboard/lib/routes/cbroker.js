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

var http = require('http'),
    domain = require("domain"),
    logger = require('../logger'),
    config = require('../www');


var SANITY_STATUS_ATTRIBUTE = 'sanity_status', // field name for value about regions status
    REGION_TYPE = "region";


/**
 * @function parseRegions
 *
 * @param {Object} entities
 * @return {Array}
 */
function parseRegions(entities) {

    var result = [];

    logger.debug("entities to parse" + entities);
    entities.contextResponses.forEach(function (entry) {
        var type = entry.contextElement.type;
        if (type === REGION_TYPE) {
            var sanity_status = '';
            entry.contextElement.attributes.forEach(function (value) {
                if (value.name === SANITY_STATUS_ATTRIBUTE) {
                    sanity_status = value.value;
                }
            });
            result.push({node: entry.contextElement.id, status: sanity_status});
        }
    });


    return result;
}

/**
 * @function postAllRegions
 * Call to context broker and get all regions and status.
 * @param {function} callback
 */
function retrieveAllRegions(callback) {

    var payload = {entities: [
        {type: 'region', isPattern: 'true', id: '.*'}
    ], attributes: [SANITY_STATUS_ATTRIBUTE]};
    var payloadString = JSON.stringify(payload);
    var headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Content-Length': payloadString.length
    };

    logger.debug("using configuration: " + JSON.stringify(config.cbroker));
    var options = {
        host: config.cbroker.host,
        port: config.cbroker.port,
        path: config.cbroker.path,
        method: 'POST',
        headers: headers
    };

    var req = http.request(options, function (res) {
        res.setEncoding('utf-8');
        var responseString = '';

        res.on('data', function (data) {
            responseString += data;
        });
        res.on('end', function () {
            var resultObject = JSON.parse(responseString);
            callback(parseRegions(resultObject));
        });
    });
    req.on('error', function (e) {
        logger.error('Error in connection with context broker: ' + e);
        callback(function () {
                return [];
            }
        );
    });


    req.write(payloadString);
    req.end();

}


/** @export */
module.exports.retrieveAllRegions = retrieveAllRegions;
/** @export */
module.exports.parseRegions = parseRegions;

