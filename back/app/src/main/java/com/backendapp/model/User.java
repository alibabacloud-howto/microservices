package com.backendapp.model;

import java.util.List;

/**
 * User class.
 */
public class User {
    private Integer id;
    private String name;
    private List<UserPurchase> purchaseList;

    public User(Integer id, String name) {
        this.id = id;
        this.name = name;
    }

    public Integer getId() {
        return id;
    }
    public void setId(Integer id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }
    public void setName(String name) {
        this.name = name;
    }

    public List<UserPurchase> getPurchaseList() {
        return purchaseList;
    }
    public void setPurchaseList(List<UserPurchase> purchaseList) {
        this.purchaseList = purchaseList;
    }
}