/*
    Copyright 2016-2017 Felspar Co Ltd. http://odin.felspar.com/
    Distributed under the Boost Software License, Version 1.0.
    See accompanying file LICENSE_1_0.txt or copy at
        http://www.boost.org/LICENSE_1_0.txt
*/

#include <odin/odin.hpp>
#include <odin/nonce.hpp>

#include <fostgres/callback.hpp>


const fostlib::module odin::c_odin("odin");


const fostlib::setting<fostlib::string> odin::c_jwt_secret(
    "odin/odin.cpp", "odin", "JWT secret", odin::nonce(), true);
const fostlib::setting<bool> odin::c_jwt_trust(
    "odin/odin.cpp", "odin", "Trust JWT", false, true);

const fostlib::setting<fostlib::string> odin::c_jwt_logout_claim(
    "odin/odin.cpp", "odin", "JWT logout claim", "http://odin.felspar.com/lo", true);
const fostlib::setting<bool> odin::c_jwt_logout_check(
    "odin/odin.cpp", "odin", "Perform JWT logout check", true, true);

const fostlib::setting<fostlib::string> odin::c_jwt_permissions_claim(
    "odin/odin.cpp", "odin", "JWT permissions claim", "http://odin.felspar.com/p", true);


namespace {
    const fostgres::register_cnx_callback c_cb(
        [](fostlib::pg::connection &cnx, const fostlib::http::server::request &req) {
            if ( req.headers().exists("__user") ) {
                const auto &user = req.headers()["__user"];
                cnx.set_session("odin.jwt.sub", user.value());
            }
            if ( req.headers().exists("__jwt") ) {
                for ( const auto &sv : req.headers()["__jwt"] )
                    cnx.set_session("odin.jwt." + sv.first, sv.second);
            }
        });
}

