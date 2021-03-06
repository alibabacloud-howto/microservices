package com.backendapp.model;


/**
 * User purchase in the database.
 */
public class UserPurchase {

    Integer id;
    Integer userId;
    String item;
    String place;

    public UserPurchase() {}
    public UserPurchase(Integer id, Integer userId, String item, String place) {
        this.id = id;
        this.userId = userId;
        this.item = item;
        this.place = place;
    }

    public Integer getId() {
        return id;
    }
    public void setId(Integer id) {
        this.id = id;
    }

    public Integer getUserId() {
        return userId;
    }
    public void setUserId(Integer userId) {
        this.userId = userId;
    }

    public String getItem() {
        return item;
    }
    public void setItem(String item) {
        this.item = item;
    }

    public String getPlace() {
        return place;
    }
    public void setPlace(String place) {
        this.place = place;
    }
}