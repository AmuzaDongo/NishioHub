"use client";

import { createContext, useContext, useEffect, useState } from "react";
import api from "@/lib/axios";

type Role = {
  id: number;
  name: string;
};

const RoleContext = createContext<Role[] | null>(null);

export const RoleProvider = ({ children }: { children: React.ReactNode }) => {
  const [roles, setRoles] = useState<Role[]>([]);

  useEffect(() => {
    let active = true;

    api
      .get("/roles/mentor-mentee")
      .then((res) => {
        if (active) setRoles(res.data);
      })
      .catch((error) => {
        console.error("Failed to load roles:", error);
        if (active) setRoles([]);
      });

    return () => {
      active = false;
    };
  }, []);

  return (
    <RoleContext.Provider value={roles}>
      {children}
    </RoleContext.Provider>
  );
};

export const useRoles = () => {
  const context = useContext(RoleContext);
  if (!context) {
    throw new Error("useRoles must be used within a RoleProvider");
  }
  return context;
};
