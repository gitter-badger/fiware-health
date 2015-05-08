# -*- coding: utf-8 -*-

# Copyright 2015 Telefónica Investigación y Desarrollo, S.A.U
#
# This file is part of FIWARE project.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
#
# You may obtain a copy of the License at:
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#
# See the License for the specific language governing permissions and
# limitations under the License.
#
# For those usages not covered by the Apache version 2.0 License please
# contact with opensource@tid.es


import dbus
from dbus import SystemBus
from dbus.exceptions import DBusException
from dbus.service import BusName
from dbus.mainloop.glib import DBusGMainLoop
import gobject
from commons.constants import PHONEHOME_DBUS_NAME, PHONEHOME_TIMEOUT


class DbusPhoneHomeClient():

    def __init__(self, logger):
        """
        Init the DBus client and create a new System bus
        :param logger: Logger
        :return: None
        """

        # Get the SystemBus
        self.logger = logger
        self.logger.debug("Creating session in SystemBus")
        self.bus = SystemBus()
        self.phonehome_interface = None

    def connect(self, bus_name, object_path):
        """
        Connect to Bus and get the published object (PhoneHome DBus object). The proxy are translated into
         method calls on the remote object.
        :param bus_name: str
                A bus name (either the unique name or a well-known name)
                of the application owning the object. The keyword argument
                named_service is a deprecated alias for this. PhoneHome DBus service.
        :param object_path: str
                The object path of the desired PhoneHome Object.
        :return: True if connected; False if the bus or the published object could not be found
        """

        self.logger.debug("Connecting to PhoneHome DBus Service in bus '%s' and getting PhoneHome object "
                          "with path '%s'", bus_name, object_path)
        try:
            object = self.bus.get_object(bus_name, object_path)
            self.phonehome_interface = dbus.Interface(object, bus_name)
        except DBusException as e:
            self.logger.error("PhoneHome bus or object not found: %s", str(e))
            return False

        return True

    def send_data_and_quit_server(self, data):
        """
        This methods send data to the PhoneHome DBus object.
        :return:
        """

        self.logger.debug("Executing 'Call' method from the PhoneHome object found")
        reply = self.phonehome_interface.call(data)
        self.logger.debug("Response from 'Call' method was: %s", reply)

        # Execuite 'quit' method for closing the PhoneHome service
        self.phonehome_interface.quit()


class DbusHomePhoneObject(dbus.service.Object):

    def __init__(self, logger, object_path):
        """
        Creates and registers a new PhoneHome service in the bus.
        :param object_path: str
                The object path of the desired PhoneHome Object.
        :return:
        """
        self.logger = logger
        self.phonehome_data = None
        self.loop = None
        self.logger.debug("Creating PhoneHome Object in the path '%s' and registering the Bus '%s'",
                          object_path, PHONEHOME_DBUS_NAME)
        bus = BusName(PHONEHOME_DBUS_NAME, bus=SystemBus())
        dbus.service.Object.__init__(self, bus, object_path)

    @dbus.service.method(PHONEHOME_DBUS_NAME)
    def call(self, data):
        """
        This method receives the PhoneHome data and save it in the object
        :return : String to inform that all was OK
        """
        self.logger.debug("'Call' request received. Content: %s", str(data))
        self.phonehome_data = data
        return "200 OK - Content received"

    @dbus.service.method(PHONEHOME_DBUS_NAME)
    def quit(self):
        """
        Removes this object from the DBUS connection and exits
        """
        self.logger.debug("'Quit' request received. Removing the object from DBus and exiting")
        self.remove_from_connection()
        self.loop.quit()
        self.logger.debug("Object removed and connection closed.")


class DbusHomePhoneServer():

    def __init__(self, logger, phonehome_object_path):
        """
        Inits the DbusHomePhoneServer.
        :param phonehome_object_path: str
                The object path tho server the desired PhoneHome Object. Format: /xxx/...
        :param logger: Logger
        :return:
        """
        self.logger = logger
        self.phonehome_object_path = phonehome_object_path
        self.logger.debug("Creating Dbus HomePhone Server")
        DBusGMainLoop(set_as_default=True)

    @staticmethod
    def timeout(mainloop, logger, *args):
        """
        Timeout function for the Server
        :param mainloop: Loop manager (MainLoop)
        :param logger: Logger
        :param args: Rest of arguments
        :return: False. The function is called repeatedly until it returns FALSE,
         at which point the timeout is automatically destroyed and the function will not be called again.
        """
        logger.debug("Timed out! Aborting Dbus PhoneHome Service")
        mainloop.quit()
        return False

    def start(self):
        self.logger.debug("Registering new PhoneHome Object in the Bus")
        dbus_homephone_object = DbusHomePhoneObject(self.logger, self.phonehome_object_path)
        loop = gobject.MainLoop()
        dbus_homephone_object.loop = loop

        phonehome_timeout = PHONEHOME_TIMEOUT*1000
        self.logger.debug("Setting time out: %d", phonehome_timeout)
        gobject.timeout_add(phonehome_timeout, self.timeout, loop, self.logger, priority=100)

        self.logger.debug("Running Dbus PhoneHome Service")
        loop.run()
        self.logger.debug("Dbus PhoneHome Service stopped")
        return dbus_homephone_object.phonehome_data
