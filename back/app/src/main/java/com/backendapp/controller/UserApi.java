package com.backendapp.controller;

import com.backendapp.model.User;
import com.backendapp.model.UserPurchase;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.io.*;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.ProtocolException;
import java.net.URL;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;

/**
 * REST API about {@link User}.
 */
@RestController
public class UserApi {

    @Value("${database.api.endpoint}")
    private String DATABASE_API_ENDPOINT;

    /**
     * User data.
     * For simplicity, the data is embedded.
     */
    private static final List<User> users = Arrays.asList(
            new User(999999, "Default"),
            new User(1, "Adam"),
            new User(2, "Ben"),
            new User(3, "Chris")
    );

    /**
     * Get a user.
     * It's using * for simplicity. Please configure CORS setting properly in production.
     */
    @CrossOrigin(origins = { "*" })
    @RequestMapping(value = "/api/user", produces = MediaType.APPLICATION_JSON_UTF8_VALUE)
    public String apiUser(@RequestParam(value = "id", defaultValue = "999999") Integer id) {
        final Optional<User> foundFirstUser = users.stream().filter(u -> u.getId().equals(id)).findFirst();
        if (!foundFirstUser.isPresent()) {
            return objectToString(users.get(0));
        }

        User user = foundFirstUser.get();
        List<UserPurchase> userPurchaseList = getUserPurchaseList(user.getId());

        user.setPurchaseList(userPurchaseList);

        return objectToString(user);
    }

    /**
     * Json util.
     */
    private String objectToString(Object object) {
        final ObjectMapper mapper = new ObjectMapper();
        try {
            return mapper.writeValueAsString(object);
        } catch (JsonProcessingException e) {
            e.printStackTrace();
        }
        return "";
    }

    /**
     * Get user purchase list by user ID from database API.
     */
    private List<UserPurchase> getUserPurchaseList(Integer userId) {
        final String requestUrl = DATABASE_API_ENDPOINT + "/api/userpurchase?uid=" + userId;

        HttpURLConnection con = null;
        InputStream in = null;
        InputStreamReader inReader = null;
        BufferedReader bufferedReader = null;

        try {
            // configure request
            URL url = new URL(requestUrl);
            con = (HttpURLConnection) url.openConnection();
            con.setConnectTimeout(3000);
            con.setRequestMethod("GET");
            con.setUseCaches(false);
            con.setDoInput(true);
            con.setRequestProperty("Content-Type", "application/json; charset=utf-8");

            // do request
            con.connect();
            String responseJson = null;
            if (con.getResponseCode() == HttpURLConnection.HTTP_OK) {
                StringBuilder result = new StringBuilder();

                in = con.getInputStream();
                inReader = new InputStreamReader(in, "utf-8");
                bufferedReader = new BufferedReader(inReader);
                String line = null;
                while((line = bufferedReader.readLine()) != null) {
                    result.append(line);
                }
                bufferedReader.close();
                inReader.close();
                in.close();

                responseJson = result.toString();
            }
            con.disconnect();
            if (responseJson == null) return null;

            // adjust and return response
            final ObjectMapper mapper = new ObjectMapper();
            return mapper.readValue(responseJson,
                    mapper.getTypeFactory().constructCollectionType(ArrayList.class, UserPurchase.class));

        } catch (MalformedURLException e) {
            e.printStackTrace();
        } catch (ProtocolException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            try {
                if (bufferedReader != null) {
                    bufferedReader.close();
                }
                if (inReader != null) {
                    inReader.close();
                }
                if (in != null) {
                    in.close();
                }
                if (con != null) {
                    con.disconnect();
                }
            } catch (IOException e) {
                e.printStackTrace();
            }
        }

        return null;
    }
}