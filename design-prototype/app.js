const statusOptions = [
  { id: 1, label: "Requested", code: "requested", className: "status-requested" },
  { id: 2, label: "Approved", code: "approved", className: "status-approved" },
  { id: 3, label: "Pending", code: "pending", className: "status-pending" },
  { id: 4, label: "Collected", code: "collected", className: "status-collected" },
  { id: 5, label: "Returned", code: "returned", className: "status-returned" },
  { id: 6, label: "Used", code: "used", className: "status-used" },
  { id: 7, label: "Disposed", code: "disposed", className: "status-disposed" },
];

const selectableStatusOptions = statusOptions.filter((status) =>
  ["approved", "pending", "collected", "returned"].includes(status.code),
);

const brands = [
  { id: 1, name: "Canon" },
  { id: 2, name: "Fuji Xerox" },
  { id: 3, name: "Ricoh" },
];

const brandModels = [
  { id: 11, brand_id: 1, name: "iR ADV DX C3926" },
  { id: 12, brand_id: 1, name: "imagePRESS C270" },
  { id: 21, brand_id: 2, name: "Apeos C7070" },
  { id: 31, brand_id: 3, name: "IM C3000" },
];

const machines = [
  { id: 101, name: "HQ Printer A", user_id: 7 },
  { id: 102, name: "Branch Copier 02", user_id: 8 },
  { id: 103, name: "Warehouse Unit 4", user_id: 9 },
];

const categories = [
  { id: 201, name: "Drum Unit" },
  { id: 202, name: "Fuser Assembly" },
  { id: 203, name: "Toner Supply" },
  { id: 204, name: "Paper Feed" },
];

const users = [
  { id: 7, name: "Aisyah" },
  { id: 8, name: "Farhan" },
  { id: 9, name: "Nina" },
];

const requests = [
  {
    id: 5001,
    brand_id: 1,
    brand_model_id: 11,
    machine_id: 101,
    part_category_id: 201,
    part_name: "Cyan Drum Kit",
    status: 1,
    cost: 780,
    description: "Drum count is high and print quality shows repeated marks.",
    remark: "Need urgent approval before next PM cycle.",
    user_id: 7,
    created_at: "2026-04-02",
  },
  {
    id: 5002,
    brand_id: 2,
    brand_model_id: 21,
    machine_id: 102,
    part_category_id: 202,
    part_name: "Upper Fuser Roller",
    status: 2,
    cost: 1260,
    description: "Temperature inconsistency causing wrinkled output during long runs.",
    remark: "Approved for store processing after quote verification.",
    user_id: 8,
    created_at: "2026-04-01",
  },
  {
    id: 5003,
    brand_id: 3,
    brand_model_id: 31,
    machine_id: 103,
    part_category_id: 204,
    part_name: "Pickup Roller Set",
    status: 3,
    cost: 180,
    description: "Waiting for warehouse allocation before the technician can collect it.",
    remark: "Pending stock release from central store.",
    user_id: 9,
    created_at: "2026-03-29",
  },
  {
    id: 5004,
    brand_id: 1,
    brand_model_id: 12,
    machine_id: 101,
    part_category_id: 203,
    part_name: "Magenta Toner Bottle",
    status: 4,
    cost: 0,
    description: "Collected from store and prepared for the next preventive maintenance visit.",
    remark: "Technician collection logged at service counter.",
    user_id: 7,
    created_at: "2026-03-28",
  },
  {
    id: 5005,
    brand_id: 2,
    brand_model_id: 21,
    machine_id: 102,
    part_category_id: 203,
    part_name: "Black Toner Cartridge",
    status: 5,
    cost: 340,
    description: "Requested quantity does not match actual machine consumption history.",
    remark: "Returned to technician for revised justification.",
    user_id: 8,
    created_at: "2026-03-27",
  },
  {
    id: 5006,
    brand_id: 3,
    brand_model_id: 31,
    machine_id: 103,
    part_category_id: 201,
    part_name: "Waste Toner Bottle",
    status: 6,
    cost: 95,
    description: "Collected part was installed successfully during the scheduled visit.",
    remark: "Used on-site and job sheet updated.",
    user_id: 9,
    created_at: "2026-03-26",
  },
  {
    id: 5007,
    brand_id: 3,
    brand_model_id: 31,
    machine_id: 103,
    part_category_id: 201,
    part_name: "Waste Toner Bottle",
    status: 7,
    cost: 95,
    description: "Old consumable was removed after replacement and marked for disposal.",
    remark: "Disposed according to site handling procedure.",
    user_id: 9,
    created_at: "2026-03-25",
  },
];

const state = {
  authenticated: false,
  filters: {
    query: "",
    status: "",
    part_category_id: "",
    machine_id: "",
    user_id: "",
    from: "",
    to: "",
  },
  requests: structuredClone(requests),
};

const apiReference = {
  list: "GET /api/mobile/part-request",
  create: "POST /api/mobile/part-request",
  show: "GET /api/mobile/part-request/{id}",
  update: "PUT /api/mobile/part-request/{id}",
  search: "POST /api/mobile/search/part-requests",
};

const loginForm = document.querySelector("#login-form");
const loginScreen = document.querySelector('[data-screen="login"]');
const dashboardScreen = document.querySelector('[data-screen="dashboard"]');
const requestList = document.querySelector("#request-list");
const requestCount = document.querySelector("#request-count");
const summaryGrid = document.querySelector("#summary-grid");
const detailModal = document.querySelector("#detail-modal");
const createModal = document.querySelector("#create-modal");
const detailBody = document.querySelector("#detail-body");
const detailTitle = document.querySelector("#detail-title");
const filtersPanel = document.querySelector("#filters-panel");

initialize();

function initialize() {
  hydrateSelects();
  attachEvents();
  renderApp();
}

function hydrateSelects() {
  populateSelect("#filter-status", selectableStatusOptions, "label");
  populateSelect("#filter-category", categories, "name");
  populateSelect("#filter-machine", machines, "name");
  populateSelect("#filter-user", users, "name");

  populateSelect("#brand_id", brands, "name", true);
  populateSelect("#brand_model_id", brandModels, "name", true);
  populateSelect("#machine_id", [{ id: "", name: "No machine selected" }, ...machines], "name", true);
  populateSelect("#part_category_id", categories, "name", true);
  populateSelect("#status", statusOptions, "label", true);
}

function populateSelect(selector, items, labelKey, overwrite = false) {
  const element = document.querySelector(selector);
  if (!element) return;

  if (overwrite) {
    element.innerHTML = "";
  }

  if (!overwrite && element.options.length > 1) {
    return;
  }

  items.forEach((item) => {
    const option = document.createElement("option");
    option.value = item.id;
    option.textContent = item[labelKey];
    element.append(option);
  });
}

function attachEvents() {
  loginForm.addEventListener("submit", (event) => {
    event.preventDefault();
    state.authenticated = true;
    renderApp();
  });

  document.querySelector("#logout-btn").addEventListener("click", () => {
    state.authenticated = false;
    renderApp();
  });

  document.querySelector("#search-input").addEventListener("input", (event) => {
    state.filters.query = event.target.value.trim().toLowerCase();
    renderList();
  });

  document.querySelector("#toggle-filters-btn").addEventListener("click", () => {
    filtersPanel.classList.toggle("hidden");
  });

  document.querySelector("#apply-filters-btn").addEventListener("click", () => {
    state.filters.status = document.querySelector("#filter-status").value;
    state.filters.part_category_id = document.querySelector("#filter-category").value;
    state.filters.machine_id = document.querySelector("#filter-machine").value;
    state.filters.user_id = document.querySelector("#filter-user").value;
    state.filters.from = document.querySelector("#filter-from").value;
    state.filters.to = document.querySelector("#filter-to").value;
    renderList();
  });

  document.querySelector("#open-create-btn").addEventListener("click", () => {
    createModal.classList.remove("hidden");
  });

  document.querySelector("#close-create-btn").addEventListener("click", () => {
    createModal.classList.add("hidden");
  });

  document.querySelector("#close-detail-btn").addEventListener("click", () => {
    detailModal.classList.add("hidden");
  });

  document.querySelector("#create-form").addEventListener("submit", (event) => {
    event.preventDefault();
    const formData = new FormData(event.target);
    const nextId = Math.max(...state.requests.map((item) => item.id)) + 1;
    const payload = {
      id: nextId,
      brand_id: Number(formData.get("brand_id") || document.querySelector("#brand_id").value),
      brand_model_id: Number(
        formData.get("brand_model_id") || document.querySelector("#brand_model_id").value,
      ),
      machine_id: Number(document.querySelector("#machine_id").value) || null,
      part_category_id: Number(
        formData.get("part_category_id") || document.querySelector("#part_category_id").value,
      ),
      part_name: document.querySelector("#part_name").value || "Unnamed part request",
      status: Number(document.querySelector("#status").value),
      cost: Number(document.querySelector("#cost").value || 0),
      description: document.querySelector("#description").value || "",
      remark: document.querySelector("#remark").value || "",
      user_id: 7,
      created_at: new Date().toISOString().slice(0, 10),
    };

    state.requests.unshift(payload);
    event.target.reset();
    createModal.classList.add("hidden");
    renderApp();
  });

  document.querySelector("#brand_id").addEventListener("change", (event) => {
    const modelSelect = document.querySelector("#brand_model_id");
    const filtered = brandModels.filter((model) => model.brand_id === Number(event.target.value));
    modelSelect.innerHTML = "";
    populateSelect("#brand_model_id", filtered, "name", true);
  });
}

function renderApp() {
  loginScreen.classList.toggle("active", !state.authenticated);
  dashboardScreen.classList.toggle("active", state.authenticated);
  if (state.authenticated) {
    renderSummary();
    renderList();
  }
}

function renderSummary() {
  const totals = statusOptions.map((status) => ({
    label: status.label,
    value: state.requests.filter((item) => item.status === status.id).length,
  }));

  summaryGrid.innerHTML = totals
    .map(
      (item) => `
        <article>
          <strong>${item.value}</strong>
          <span>${item.label}</span>
        </article>
      `,
    )
    .join("");
}

function renderList() {
  const filtered = filterRequests();
  requestCount.textContent = `${filtered.length} items`;

  if (!filtered.length) {
    requestList.innerHTML = `
      <div class="empty-state">
        No part requests matched the current filters.
      </div>
    `;
    return;
  }

  const template = document.querySelector("#request-card-template");
  requestList.innerHTML = "";

  filtered.forEach((request) => {
    const fragment = template.content.cloneNode(true);
    const card = fragment.querySelector(".request-card");
    const main = fragment.querySelector(".request-main");
    const requestId = fragment.querySelector(".request-id");
    const requestName = fragment.querySelector(".request-name");
    const statusPill = fragment.querySelector(".status-pill");
    const requestMeta = fragment.querySelector(".request-meta");
    const requestDescription = fragment.querySelector(".request-description");
    const floatingGroup = fragment.querySelector(".floating-status-group");
    const activeStatus = statusOptions.find((item) => item.id === request.status);

    requestId.textContent = `PR-${request.id}`;
    requestName.textContent = request.part_name || categoryName(request.part_category_id);
    statusPill.textContent = activeStatus.label;
    statusPill.classList.add(activeStatus.className);
    requestMeta.innerHTML = `
      <span>${brandName(request.brand_id)}</span>
      <span>${modelName(request.brand_model_id)}</span>
      <span>${machineName(request.machine_id) || "No machine"}</span>
      <span>RM ${request.cost.toFixed(2)}</span>
      <span>${request.created_at}</span>
    `;
    requestDescription.textContent = request.description || "No description provided.";

    selectableStatusOptions.forEach((status) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = `status-fab ${status.className}`;
      if (status.id === request.status) {
        button.classList.add("is-active");
      }
      button.innerHTML = `<small>${status.id}</small>${status.label}`;
      button.addEventListener("click", (event) => {
        event.stopPropagation();
        request.status = status.id;
        renderSummary();
        renderList();
      });
      floatingGroup.append(button);
    });

    main.addEventListener("click", () => openDetail(request));
    card.dataset.id = request.id;
    requestList.append(fragment);
  });
}

function filterRequests() {
  return state.requests.filter((request) => {
    const haystack = [
      request.part_name,
      request.description,
      brandName(request.brand_id),
      modelName(request.brand_model_id),
      machineName(request.machine_id),
      categoryName(request.part_category_id),
    ]
      .join(" ")
      .toLowerCase();

    const queryMatch = !state.filters.query || haystack.includes(state.filters.query);
    const statusMatch = !state.filters.status || request.status === Number(state.filters.status);
    const categoryMatch =
      !state.filters.part_category_id ||
      request.part_category_id === Number(state.filters.part_category_id);
    const machineMatch =
      !state.filters.machine_id || request.machine_id === Number(state.filters.machine_id);
    const userMatch = !state.filters.user_id || request.user_id === Number(state.filters.user_id);
    const fromMatch = !state.filters.from || request.created_at >= state.filters.from;
    const toMatch = !state.filters.to || request.created_at <= state.filters.to;

    return (
      queryMatch &&
      statusMatch &&
      categoryMatch &&
      machineMatch &&
      userMatch &&
      fromMatch &&
      toMatch
    );
  });
}

function openDetail(request) {
  const currentStatus = statusOptions.find((item) => item.id === request.status);
  detailTitle.textContent = request.part_name || `PR-${request.id}`;
  detailBody.innerHTML = `
    <div class="detail-card">
      <div class="detail-grid">
        ${detailRow("Request ID", `PR-${request.id}`)}
        ${detailRow("Status", currentStatus.label)}
        ${detailRow("Brand", brandName(request.brand_id))}
        ${detailRow("Model", modelName(request.brand_model_id))}
        ${detailRow("Machine", machineName(request.machine_id) || "No machine")}
        ${detailRow("Category", categoryName(request.part_category_id))}
        ${detailRow("Cost", `RM ${request.cost.toFixed(2)}`)}
        ${detailRow("Created", request.created_at)}
      </div>
    </div>
    <div class="detail-card">
      <p class="detail-label">Description</p>
      <p class="detail-value">${request.description || "No description provided."}</p>
    </div>
    <div class="detail-card">
      <p class="detail-label">Remark</p>
      <p class="detail-value">${request.remark || "No remark provided."}</p>
    </div>
    <div class="detail-card">
      <p class="detail-label">API mapping</p>
      <p class="detail-value">${apiReference.show}</p>
      <p class="detail-value">${apiReference.update}</p>
    </div>
  `;
  detailModal.classList.remove("hidden");
}

function detailRow(label, value) {
  return `
    <div>
      <p class="detail-label">${label}</p>
      <p class="detail-value">${value}</p>
    </div>
  `;
}

function brandName(id) {
  return brands.find((item) => item.id === id)?.name || "Unknown brand";
}

function modelName(id) {
  return brandModels.find((item) => item.id === id)?.name || "Unknown model";
}

function machineName(id) {
  return machines.find((item) => item.id === id)?.name || "";
}

function categoryName(id) {
  return categories.find((item) => item.id === id)?.name || "Unknown category";
}
